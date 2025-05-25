/*
* SPDX-License-Identifier: GPL-3.0-or-later
* SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>
*
* Authored by: Colin Kiama <colinkiama@gmail.com>
*/
const long SECONDS_IN_MICROSECONDS = 1000000; // 1 Million microseconds = 1 second;

public enum IndexerMessageType {
    INITIAL,
    PROJECT_UPDATE
}

public enum IndexerStatus {
    INITIALISING,
    INITIAL_PROCESSING,
    IDLE,
    PROCESSING
}

public enum ProjectUpdateType {
    ADDED,
    REMOVED,
    FILE_CREATED,
    DIRECTORY_CREATED,
    FILE_DELETED
}

public interface IndexerMessage : GLib.Object {
    public abstract IndexerMessageType message_type { get; construct; }
}

public class InitialIndexRequest : GLib.Object, IndexerMessage {
    public IndexerMessageType message_type { get; construct; }
    public string project_path { get; construct; }

    public InitialIndexRequest (string project_path) {
        Object (
            message_type: IndexerMessageType.INITIAL,
            project_path: project_path
        );
    }
}

public class ProjectUpdate : GLib.Object, IndexerMessage {
    public IndexerMessageType message_type { get; construct; }
    public ProjectUpdateType update_type { get; construct; }
    public string source_path { get; construct; }
    public string? destination_path { get; construct; }
    public string? project_path { get; construct; }

    public ProjectUpdate (ProjectUpdateType update_type, string source_path, string? destination_path = null) {
        Object (
            message_type: IndexerMessageType.PROJECT_UPDATE,
            update_type: update_type,
            source_path: source_path,
            destination_path: destination_path
        );
    }
}

public class Scratch.Services.FuzzySearchIndexer : GLib.Object {
    public Gee.HashMap<string, Services.SearchProject> project_paths { get; private set; }

    private Gee.ArrayList<InitialIndexRequest> initial_indexing_queue;
    private GLib.Settings folder_settings;
    private GLib.Cancellable cancellable;
    private Gee.ConcurrentList<IndexerMessage> processing_queue;
    private IndexerStatus status;

    public FuzzySearchIndexer (GLib.Cancellable cancellable) {
        this.cancellable = cancellable;
        status = IndexerStatus.INITIALISING;
        initial_indexing_queue = new Gee.ArrayList<InitialIndexRequest> ();
        processing_queue = new Gee.ConcurrentList<IndexerMessage> ();
        project_paths = new Gee.HashMap<string, Services.SearchProject> ();

        folder_settings = new GLib.Settings (Constants.PROJECT_NAME + ".folder-manager");
        folder_settings.changed["opened-folders"].connect (handle_opened_projects_change);
    }

    public void handle_folder_item_change (GLib.File source, GLib.File? dest, GLib.FileMonitorEvent event) {
        switch (event) {
            case GLib.FileMonitorEvent.CREATED:
                string path = source.get_path ();
                bool is_directory = FileUtils.test (path, GLib.FileTest.IS_DIR);

                var project_update = new ProjectUpdate (
                    is_directory ? ProjectUpdateType.DIRECTORY_CREATED : ProjectUpdateType.FILE_CREATED,
                    path
                );

                processing_queue.add (project_update);
                break;
            case GLib.FileMonitorEvent.DELETED:
                string path = source.get_path ();

                var project_update = new ProjectUpdate (ProjectUpdateType.FILE_DELETED, path);
                processing_queue.add (project_update);
                break;
            default:
                break;
        }
    }

    public async void start_async () {
        string[] initial_projects = folder_settings.get_strv ("opened-folders");
        if (initial_projects != null) {
            foreach (unowned string path in initial_projects) {
                initial_indexing_queue.add (new InitialIndexRequest (path));
            }
        }

        new Thread<void> (null, () => {
            while (cancellable.is_cancelled () == false) {
                switch (status) {
                    case IndexerStatus.INITIALISING:
                        if (initial_indexing_queue.size < 1 ) {
                            status = IndexerStatus.IDLE;
                            debug ("Find Project Files: Indexer is now idle!\n");
                            break;
                        }

                        if (initial_indexing_queue.size > 0) {
                            process_initial_indexing_requests_async.begin (
                                initial_indexing_queue,
                                project_paths,
                                (obj, res) => {
                                    process_initial_indexing_requests_async.end (res);
                                    status = IndexerStatus.IDLE;
                                });

                            status = IndexerStatus.INITIAL_PROCESSING;
                            debug ("Find Project Files: Indexer is now doing initial processing!");
                        }

                        break;
                    // Indexer initialization is complete, now waiting for incoming messages to process.
                    case IndexerStatus.IDLE:
                        if (processing_queue.size > 0) {
                            var first_item = processing_queue.get (0);
                            process_next_message_async.begin (first_item, (obj, res) => {
                                process_next_message_async.end (res);
                                processing_queue.remove (first_item);
                                status = IndexerStatus.IDLE;
                                debug ("Find Project Files: Indexer is now idle!");
                            });

                            status = IndexerStatus.PROCESSING;
                            debug ("Find Project Files: Indexer now processing!");
                        }
                        break;
                    case IndexerStatus.INITIAL_PROCESSING:
                    case IndexerStatus.PROCESSING:
                        break;
                    default:
                        break;
                }

                Thread.usleep (1 * SECONDS_IN_MICROSECONDS);
            }

            folder_settings.changed["opened-folders"].disconnect (handle_opened_projects_change);
            Idle.add (start_async.callback);
        });

        yield;
    }

    private async void process_next_message_async (IndexerMessage message) {
        switch (message.message_type) {
            case IndexerMessageType.PROJECT_UPDATE:
                process_project_update_async.begin ((ProjectUpdate) message, (obj, res) => {
                    process_project_update_async.end (res);
                });

                break;
            default:
                break;
        }
    }

    private async void process_project_update_async (ProjectUpdate message) {
        switch (message.update_type) {
            case ProjectUpdateType.ADDED:
                add_project_async.begin (message, (obj, res) => {
                    add_project_async.end (res);
                    debug ("Find Project Files: Added project: %s", message.source_path);
                });

                break;
            case ProjectUpdateType.REMOVED:
                remove_project (message);
                debug ("Find Project Files: Removed project: %s", message.source_path);
                break;
            case ProjectUpdateType.FILE_CREATED:
                add_file (message);
                debug ("Find Project Files: Added file: %s", message.source_path);

                break;
            case ProjectUpdateType.DIRECTORY_CREATED:
                add_directory_async.begin (message, (obj, res) => {
                    add_directory_async.end (res);
                    debug ("Find Project Files: Added directory: %s", message.source_path);
                });

                break;
            case ProjectUpdateType.FILE_DELETED:
                remove_file (message);
                debug ("Find Project Files: Deleted directory: %s", message.source_path);
                break;
        }
    }

    private void remove_file (ProjectUpdate message) {
        string path = message.source_path;
        string project_key = get_project_path_of_file (path);
        if (project_key == null) {
            return;
        }

        Services.SearchProject project_search = project_paths[project_key];
        project_search.remove_file (path, this.cancellable);
        processing_queue.remove (message);
    }

    private void add_file (ProjectUpdate message) {
        string path = message.source_path;
        string project_key = get_project_path_of_file (path);
        if (project_key == null) {
            return;
        }

        Services.SearchProject project_search = project_paths[project_key];
        project_search.add_file (path, this.cancellable);
        processing_queue.remove (message);
    }

    private async void add_directory_async (ProjectUpdate message) {
        string path = message.source_path;
        string project_key = get_project_path_of_file (path);
        if (project_key == null) {
            return;
        }

        Services.SearchProject project_search = project_paths[project_key];
        project_search.add_directory_async.begin (path, this.cancellable, (obj, res) => {
            project_search.add_directory_async.end (res);
            processing_queue.remove (message);
        });
    }

    private async void add_project_async (ProjectUpdate message) {
        string path = message.source_path;
        var monitor = Services.GitManager.get_monitored_repository (path);
        var project_search = new Services.SearchProject (path, monitor);
        project_paths[path] = project_search;

        project_search.parse_async.begin (path, this.cancellable, (obj, res) => {
            project_search.parse_async.end (res);
            processing_queue.remove (message);
        });
    }

    private void remove_project (ProjectUpdate message) {
        string path = message.source_path;
        project_paths.unset (path);
    }

    private void handle_opened_projects_change () {
        string[] opened_projects_array = folder_settings.get_strv ("opened-folders");
        var opened_projects = new Gee.ArrayList<string>.wrap (opened_projects_array);
        // Handle project additions
        foreach (string project in opened_projects) {
            if (project_paths.keys.contains (project) == false) {
                processing_queue.add (new ProjectUpdate (ProjectUpdateType.ADDED, project));
            }
        }

        // Handle project removals
        foreach (string project in project_paths.keys) {
            if (opened_projects.contains (project) == false) {
                processing_queue.add ( new ProjectUpdate (ProjectUpdateType.REMOVED, project));
            }
        }
    }

    private async void process_initial_indexing_requests_async (
        Gee.ArrayList<InitialIndexRequest> request_queue,
        Gee.HashMap<string, Services.SearchProject> project_paths) {
        for (int i = 0; i < request_queue.size; i++) {
            var request = request_queue[i];
            var monitor = Services.GitManager.get_monitored_repository (request.project_path);
            var project_search = new Services.SearchProject (request.project_path, monitor);

            project_paths[request.project_path] = project_search;
            project_search.parse_async.begin (request.project_path, cancellable, (obj, res) => {
                project_search.parse_async.end (res);
                request_queue.remove (request);
            });
        }
    }

    private string? get_project_path_of_file (string file_path) {
        var iter = project_paths.keys.iterator ();
        while (iter.next ()) {
            string project_path = iter.get ();
            if (file_path.has_prefix (project_path)) {
                return project_path;
            }
        }

        return null;
    }
}
