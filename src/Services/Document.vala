// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
                2013      Mario Guerriero <mario@elemnetaryos.org>
                2023 elementary LLC. <https://elementary.io>
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

namespace Scratch.Services {
    public enum DocumentStates {
        NORMAL,
        READONLY
    }

    public class Document : Granite.Widgets.Tab {
        private const uint LOAD_TIMEOUT_MSEC = 5000;

        public delegate void VoidFunc ();
        public signal void doc_opened ();
        public signal void doc_closed ();

        // The parent window's actions
        public unowned SimpleActionGroup actions { get; set construct; }
        public Gtk.SourceFile source_file { get; private set; }
        public Scratch.Widgets.SourceView source_view { get; private set; }

        public bool is_file_temporary {
            get {
                return file.get_path ().has_prefix (
                    ((Scratch.Application) GLib.Application.get_default ()).data_home_folder_unsaved
                );
            }
        }

        public GLib.File file {
            get {
                return source_file.location;
            }

            private set {
                source_file.set_location (value);
                source_view.location = value;
                file_changed ();
                tab_name = get_basename ();
            }
        }

        public string tab_name {
            set {
                label = value;
                tooltip = get_tab_tooltip ();
            }
        }

        private string? _mime_type = null;
        public string? mime_type {
            get {
                if (_mime_type == null) {
                    try {
                        var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE, null);
                        var content_type = info.get_attribute_as_string (FileAttribute.STANDARD_CONTENT_TYPE);
                        _mime_type = ContentType.get_mime_type (content_type);
                        return _mime_type;
                    } catch (Error e) {
                        debug (e.message);
                    }
                }

                if (_mime_type == null) {
                    _mime_type = "undefined";
                }

                return _mime_type;
            }
        }

        public bool delay_autosaving { get; set; }
        public bool inhibit_saving {
            get {
                return !loaded || completion_shown;
            }
        }
        public bool content_changed {
            get {
                return last_save_content != source_view.buffer.text;
            }
        }

        private Scratch.Services.SymbolOutline? outline  = null;
        private string original_content = ""; // For restoring to original
        public string last_save_content = ""; // For detecting internal and external changes
        private bool completion_shown = false;
        private bool loaded = false;

        private Gtk.Stack main_stack;
        private Gtk.ScrolledWindow scroll;
        private Gtk.InfoBar info_bar;
        private Gtk.SourceMap source_map;
        private Gtk.Paned outline_widget_pane;
        private DocumentManager doc_manager;
        // Used by DocumentManager
        public GLib.Cancellable save_cancellable;
        public GLib.Cancellable load_cancellable;

        // private ulong onchange_handler_id = 0; // It is used to not mark files as changed on load
        private bool mounted = true; // Mount state of the file
        private Mount mount;

        private static Pango.FontDescription? builder_blocks_font = null;
        private static Pango.FontMap? builder_font_map = null;

        public Document (SimpleActionGroup actions, File file) {
            Object (actions: actions);

            this.file = file;
            page = main_stack;
        }

        static construct {
            var fontpath = Path.build_filename (
                Constants.DATADIR, Constants.PROJECT_NAME, "fonts", "BuilderBlocks.ttf"
            );

            unowned Fc.Config config = Fc.init ();
            if (!config.add_app_font (fontpath)) {
                warning ("Unable to load Builder Blocks font, SourceView map might not be pretty");
            } else {
                builder_font_map = Pango.CairoFontMap.new_for_font_type (Cairo.FontType.FT);
                PangoFc.attach_fontconfig_to_fontmap (builder_font_map, config);
                builder_blocks_font = Pango.FontDescription.from_string ("Builder Blocks 1");
            }
        }

        construct {
            main_stack = new Gtk.Stack ();
            source_view = new Scratch.Widgets.SourceView ();

            scroll = new Gtk.ScrolledWindow (null, null) {
                expand = true
            };
            scroll.add (source_view);
            info_bar = new Gtk.InfoBar ();
            source_file = new Gtk.SourceFile ();
            source_map = new Gtk.SourceMap ();
            outline_widget_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);

            doc_manager = DocumentManager.get_instance ();

            if (builder_blocks_font != null && builder_font_map != null) {
                source_map.set_font_map (builder_font_map);
                source_map.font_desc = builder_blocks_font;
            }

            source_map.set_view (source_view);

            hide_info_bar ();

            restore_settings ();

            settings.changed.connect (restore_settings);

            var source_grid = new Gtk.Grid () {
                orientation = Gtk.Orientation.HORIZONTAL,
                column_homogeneous = false
            };
            source_grid.add (scroll);
            source_grid.add (source_map);
            outline_widget_pane.pack1 (source_grid, true, false);

            var doc_grid = new Gtk.Grid ();
            doc_grid.orientation = Gtk.Orientation.VERTICAL;
            doc_grid.add (info_bar);
            doc_grid.add (outline_widget_pane);
            doc_grid.show_all ();

            main_stack.add_named (doc_grid, "content");

            this.source_view.buffer.create_tag ("highlight_search_all", "background", "yellow", null);

            source_view.buffer.modified_changed.connect ((buffer) => {
                set_saved_status ();
                check_undoable_actions ();
            });

            source_view.buffer.changed.connect (() => {
                // May need to wait for completion to close
                // which would otherwise inhibit saving
                Idle.add (() => {
                    doc_manager.save_request.begin (
                        this, SaveReason.AUTOSAVE
                    );
                    return Source.REMOVE;
                });
            });
            source_view.completion.show.connect (() => {
                completion_shown = true;
            });

            source_view.completion.hide.connect (() => {
                completion_shown = false;
            });

            // /* Create as loaded - could be new document */
            loaded = file == null;
            ellipsize_mode = Pango.EllipsizeMode.MIDDLE;
        }


        private uint load_timout_id = 0;
        public async void open (bool force = false) {
            /* Loading improper files may hang so we cancel after a certain time as a fallback.
            * In most cases, an error will be thrown and caught. */
            if (loaded) {
                focus_in_event.disconnect (on_focus_in);
            }
            loaded = false;
            if (load_cancellable != null) { /* just in case */
                load_cancellable.cancel ();
            }

            load_cancellable = new Cancellable ();

            // If it does not exists, let's create it!
            if (!exists (load_cancellable)) {
                try {
                    FileUtils.set_contents (file.get_path (), "");
                } catch (FileError e) {
                    warning ("Cannot create file \"%s\": %s", get_basename (), e.message);
                    return;
                }
            }

            source_view.sensitive = false;
            this.working = true;

            var content_type = ContentType.from_mime_type (mime_type);

            if (!force && !(ContentType.is_a (content_type, "text/plain"))) {
                var title = _("%s Is Not a Text File").printf (get_basename ());
                var description = _("Code will not load this type of file.");
                var alert_view = new Granite.Widgets.AlertView (title, description, "dialog-warning");
                alert_view.show_action (_("Load Anyway"));
                alert_view.show_all ();
                main_stack.add_named (alert_view, "load_alert");
                main_stack.set_visible_child (alert_view);
                alert_view.action_activated.connect (() => {
                    open.begin (true);
                    alert_view.destroy ();
                });

                working = false;
                return;
            }

            while (Gtk.events_pending ()) {
                Gtk.main_iteration ();
            }

            var buffer = new Gtk.SourceBuffer (null); /* Faster to load into a separate buffer */

            load_timout_id = Timeout.add_seconds_full (GLib.Priority.HIGH, 5, () => {
                if (load_cancellable != null && !load_cancellable.is_cancelled ()) {
                    var title = _("Loading File \"%s\" Is Taking a Long Time").printf (get_basename ());
                    var description = _("Please wait while Code is loading the file.");
                    var alert_view = new Granite.Widgets.AlertView (title, description, "dialog-information");
                    alert_view.show_action (_("Cancel Loading"));
                    alert_view.show_all ();
                    main_stack.add_named (alert_view, "wait_alert");
                    main_stack.set_visible_child (alert_view);
                    alert_view.action_activated.connect (() => {
                        load_cancellable.cancel ();
                        doc_closed ();
                    });
                    load_timout_id = 0;

                    return GLib.Source.REMOVE;
                }

                load_timout_id = 0;
                return GLib.Source.REMOVE;
            });

            try {
                var source_file_loader = new Gtk.SourceFileLoader (buffer, source_file);
                yield source_file_loader.load_async (GLib.Priority.LOW, load_cancellable, null);
                var source_buffer = source_view.buffer as Gtk.SourceBuffer;
                if (source_buffer != null) {
                    source_buffer.begin_not_undoable_action ();
                    source_buffer.text = buffer.text;
                    source_buffer.end_not_undoable_action ();
                } else {
                    source_view.buffer.text = buffer.text;
                }

            } catch (Error e) {
                critical (e.message);
                source_view.buffer.text = "";
                show_default_load_error_view ();
                working = false;
                return;
            } finally {
                load_cancellable = null;
                if (load_timout_id > 0) {
                    Source.remove (load_timout_id);
                }
            }

            // Focus in event for SourceView
            focus_in_event.connect (on_focus_in);

            // Change syntax highlight
            this.source_view.change_syntax_highlight_from_file (this.file);

            source_view.buffer.set_modified (false);
            original_content = source_view.buffer.text;
            last_save_content = original_content;
            set_saved_status ();
            check_undoable_actions ();

            doc_opened ();
            source_view.sensitive = true;

            /* Do not stop working (blocks editing) until idle
             * (large documents take time to format/display after loading)
             */
            Idle.add (() => {
                working = false;
                loaded = true;
                return false;
            });

            return;
        }

        public async bool do_close (bool app_closing) {
            debug ("Closing \"%s\"", get_basename ());
            if (!loaded) {
                load_cancellable.cancel ();
                return true;
            }

            var reason = app_closing ? SaveReason.APP_CLOSING : SaveReason.TAB_CLOSING;
            if (yield doc_manager.save_request (this, reason)) {
                // DocumentManager will delete any backup
                doc_closed ();
                return true;
            }

            return false;
        }

        public async bool save () {
            return yield doc_manager.save_request (this, SaveReason.USER_REQUEST);
        }

        public async bool save_as () {
            var new_uri = get_save_as_uri ();
            assert_nonnull (new_uri);
            if (new_uri != "") {
                var old_uri = file.get_uri ();
                file = GLib.File.new_for_uri (new_uri);
                if (!(yield doc_manager.save_request (
                    this, SaveReason.USER_REQUEST))) {
                    // Revert to original location if save failed or cancelled
                    file = GLib.File.new_for_uri (old_uri);
                    return false;
                }

                return true;
            } else {
                warning ("Save As: Failed to get new uri");
                return false;
            }
        }

        public string get_save_as_uri () {
            // Get new path to save to from user
            if (!loaded) {
                return "";
            }

            var all_files_filter = new Gtk.FileFilter ();
            all_files_filter.set_filter_name (_("All files"));
            all_files_filter.add_pattern ("*");

            var text_files_filter = new Gtk.FileFilter ();
            text_files_filter.set_filter_name (_("Text files"));
            text_files_filter.add_mime_type ("text/*");

            var file_chooser = new Gtk.FileChooserNative (
                _("Save File"),
                (Gtk.Window) this.get_toplevel (),
                Gtk.FileChooserAction.SAVE,
                _("Save"),
                _("Cancel")
            );
            file_chooser.add_filter (all_files_filter);
            file_chooser.add_filter (text_files_filter);
            file_chooser.do_overwrite_confirmation = true;
            file_chooser.set_current_folder_uri (
                Utils.last_path ?? GLib.Environment.get_home_dir ()
            );

            var new_path = "";
            if (file_chooser.run () == Gtk.ResponseType.ACCEPT) {
                // Update last visited path
                new_path = file_chooser.get_file ().get_uri ();
                Utils.last_path = Path.get_dirname (new_path);
            }

            file_chooser.destroy ();

            // //Check that the location is writable
            // var new_file = File.new_for_path (new_path);
            // if (!can_write (new_file)) {
            //     new_path = "";
            // }

            return new_path;
        }

        public async bool move (File new_dest) {
            this.file = new_dest;
            return yield doc_manager.save_request (this, SaveReason.USER_REQUEST);
        }

        private void restore_settings () {
            if (Scratch.settings.get_boolean ("show-mini-map")) {
                source_map.show ();
                scroll.vscrollbar_policy = Gtk.PolicyType.EXTERNAL;
            } else {
                source_map.hide ();
                source_map.no_show_all = true;
                scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
            }
        }

        // Focus the SourceView
        public new void focus () {
            source_view.grab_focus ();
        }

        // Get file uri
        public string get_uri () {
            return this.file.get_uri ();
        }

        // Get file name
        public string get_basename () {
            assert_nonnull (file);
            if (is_file_temporary) {
                return _("New Document");
            } else {
                return file.get_basename ();
            }
        }

        // Get full file path
        public string get_tab_tooltip () {
            if (is_file_temporary) {
                return _("New Document"); //No path for a new document
            } else {
                return Scratch.Utils.replace_home_with_tilde (file.get_path ());
            }
        }

        // Set InfoBars message
        public void set_message (
            Gtk.MessageType type, string label,
            string? button1 = null,
            owned VoidFunc? callback1 = null,
            string? button2 = null,
            owned VoidFunc? callback2 = null
        ) {

            // Show InfoBar
            info_bar.no_show_all = false;
            info_bar.visible = true;

            // Clear from useless widgets
            info_bar.get_content_area ().get_children ().foreach ((widget) => {
                if (widget != null) {
                    widget.destroy ();
                }
            });

            ((Gtk.Container) info_bar.get_action_area ()).get_children ().foreach ((widget) => {
                if (widget != null) {
                    widget.destroy ();
                }
            });

            // Type
            info_bar.message_type = type;

            // Layout
            var l = new Gtk.Label (label);
            l.ellipsize = Pango.EllipsizeMode.END;
            l.use_markup = true;
            l.set_markup (label);
            ((Gtk.Box) info_bar.get_action_area ()).orientation = Gtk.Orientation.HORIZONTAL;
            var main = info_bar.get_content_area () as Gtk.Box;
            main.orientation = Gtk.Orientation.HORIZONTAL;
            main.pack_start (l, false, false, 0);
            if (button1 != null) {
                info_bar.add_button (button1, 0);
            } if (button2 != null) {
                info_bar.add_button (button2, 1);
            }

            // Response
            info_bar.response.connect ((id) => {
                if (id == 0) {
                    callback1 ();
                } else if (id == 1) {
                    callback2 ();
                }
            });

            // Show everything
            info_bar.show_all ();
        }

        // Hide InfoBar when not needed
        public void hide_info_bar () {
            source_view.focus_in_event.disconnect (on_focus_in);
            info_bar.no_show_all = true;
            info_bar.visible = false;
            Idle.add (() => {
                source_view.focus_in_event.connect (on_focus_in);
                return Source.REMOVE;
            });
        }

        // SourceView related functions
        // Undo
        public void undo () {
            this.source_view.undo ();
        }

        // Redo
        public void redo () {
            this.source_view.redo ();
        }

        // Revert
        public void revert () {
            this.source_view.set_text (original_content, false);
            source_view.buffer.set_modified (false);
            check_undoable_actions ();
            set_saved_status ();
        }

        // Get text
        public string get_text () {
            return this.source_view.buffer.text;
        }

        // Get selected text
        public string get_selected_text (bool replace_newline = true) {
            return this.source_view.get_selected_text (replace_newline);
        }

        // Get language name
        public string get_language_name () {
            var source_buffer = (Gtk.SourceBuffer) source_view.buffer;
            var lang = source_buffer.language;
            if (lang != null) {
                return lang.name;
            } else {
                return "";
            }
        }

        // Get language id
        public string get_language_id () {
            var source_buffer = (Gtk.SourceBuffer) source_view.buffer;
            var lang = source_buffer.language;
            if (lang != null) {
                return lang.id;
            } else {
                return "";
            }
        }

        // Duplicate selected text
        public void duplicate_selection () {
            this.source_view.duplicate_selection ();
        }

        // Show an error view which says "Hey, I cannot read that file!"
        private void show_default_load_error_view () {
            var title = _("File \"%s\" Cannot Be Read").printf (get_basename ());
            var description = _("It may be corrupt or you don't have permission to read it.");
            var alert_view = new Granite.Widgets.AlertView (title, description, "dialog-error");
            alert_view.show_all ();
            main_stack.add_named (alert_view, "error_alert");
            main_stack.set_visible_child (alert_view);
        }

        private bool on_focus_in () {
            // Ignore if saving underway. DocumentManager will perform same
            // operations when finished.
            if (!working) {
                check_file_status ();
                check_undoable_actions ();
            }

            return false;
        }
        // Check if the file was deleted/changed by an external source
        // Called on focus in and after failed saving
        public void check_file_status () {
            // If the file does not exist anymore
            assert (!working);
            if (!exists ()) {
                if (mounted == false) {
                    string message = _(
                        "The location containing the file \"%s\" was unmounted. Do you want to save somewhere else?"
                    ).printf ("<b>%s</b>".printf (get_basename ()));

                    set_message (Gtk.MessageType.WARNING, message, _("Save As…"), () => {
                        save_as.begin ((obj, res) => {
                            if (save_as.end (res)) {
                                hide_info_bar ();
                            }
                        });
                    });
                } else {
                    string message = _(
                        "File \"%s\" was deleted. Do you want to save it anyway?"
                    ).printf ("<b>%s</b>".printf (get_basename ()));

                    set_message (Gtk.MessageType.WARNING, message, _("Save"), () => {
                        save.begin ((obj, res) => {
                            if (save.end (res)) {
                                hide_info_bar ();
                            }
                        });
                    });
                }

                Utils.action_from_group (MainWindow.ACTION_SAVE, actions).set_enabled (false);
                this.source_view.editable = false;
                return;
            }

            // If the file can't be written
            if (!can_write ()) {
                string message = _(
                    "You cannot save changes to the file \"%s\". Do you want to save the changes somewhere else?"
                ).printf ("<b>%s</b>".printf (get_basename ()));

                set_message (Gtk.MessageType.WARNING, message, _("Save changes elsewhere"), () => {
                    save_as.begin ((obj, res) => {
                        if (save_as.end (res)) {
                            hide_info_bar ();
                        }
                    });
                });

                Utils.action_from_group (MainWindow.ACTION_SAVE, actions).set_enabled (false);
                this.source_view.editable = !Scratch.settings.get_boolean ("autosave");
            } else {
                Utils.action_from_group (MainWindow.ACTION_SAVE, actions).set_enabled (true);
                this.source_view.editable = true;
            }

            // Detect external changes
            if (loaded) {
                var new_buffer = new Gtk.SourceBuffer (null);
                var source_file_loader = new Gtk.SourceFileLoader (new_buffer, source_file);
                source_file_loader.load_async.begin (GLib.Priority.DEFAULT, null, null, (obj, res) => {
                    try {
                        source_file_loader.load_async.end (res);
                    } catch (Error e) {
                        critical (e.message);
                        show_default_load_error_view ();
                        return;
                    }

                    if (last_save_content == new_buffer.text) {
                        return;
                    }

warning ("last save content not equal to new_buffer.text");
                    // In case of conflict, either discard current changes and load external changes
                    // or continue. If continuing, the user can later rename this document to keep
                    // external changes or overwrite them by saving with the same name.
                    string message;
                    if (!source_view.buffer.get_modified ()) {
                        message = _(
"File \"%s\" was modified by an external application.\n Do you want to load the external changes or continue and overwrite the external changes if you save this document?"
                        ).printf ("<b>%s</b>".printf (get_basename ()));
                    } else {
                        message = _(
"File \"%s\" was modified by an external application while you were also making changes.\n Do you want to load the external changes and lose your changes or continue and overwrite the external changes if you save this document?"
                        ).printf ("<b>%s</b>".printf (get_basename ()));
                    }

                    set_message (Gtk.MessageType.WARNING, message,
                        _("Load"),
                        () => {
                            source_view.set_text (new_buffer.text, false);
                            // Put in "saved" state
                            last_save_content = new_buffer.text;
                            source_view.buffer.set_modified (false);
                            check_undoable_actions ();
                            set_saved_status ();
                            hide_info_bar ();
                        },
                        _("Continue"),
                        () => {
                            hide_info_bar ();
                        }
                    );
                });
            }
        }

        // Set Undo/Redo action sensitive property
        public void check_undoable_actions () {
            var source_buffer = (Gtk.SourceBuffer) source_view.buffer;
            Utils.action_from_group (MainWindow.ACTION_UNDO, actions).set_enabled (source_buffer.can_undo);
            Utils.action_from_group (MainWindow.ACTION_REDO, actions).set_enabled (source_buffer.can_redo);
            Utils.action_from_group (MainWindow.ACTION_REVERT, actions).set_enabled (
                //This reverts to original loaded content, not to last saved content!
                source_view.buffer.text != original_content
            );
        }

        // Two functions Used by SearchBar when search/replacing as well as
        // DocumentManager while saving in order to prevent user changing the
        // the document during critical operations, and to update things after.
        public void before_undoable_change () {
            source_view.set_editable (false);
        }
        public void after_undoable_change () {
            source_view.set_editable (true);
            set_saved_status ();

            if (outline != null) {
                outline.parse_symbols ();
            }
        }

        // Show whether there are unsaved changes in the tab label
        public void set_saved_status () {
            string unsaved_identifier = "* ";
            if (source_view.buffer.get_modified ()) {
                if (!(unsaved_identifier in this.label)) {
                    tab_name = unsaved_identifier + this.label;
                }
            } else {
                tab_name = this.label.replace (unsaved_identifier, "");
            }
        }

        // Return true if the file is writable. Keep testing as may change
        public bool can_write (GLib.File test_file = this.file) {
            FileInfo info;
            bool writable = false;
            try {
                info = test_file.query_info (
                    FileAttribute.ACCESS_CAN_WRITE,
                    FileQueryInfoFlags.NONE,
                    null
                );
                writable = info.get_attribute_boolean (
                    FileAttribute.ACCESS_CAN_WRITE
                );
            } catch (Error e) {
                critical (
                    "Error determining write access: %s. Not allowing write",
                     e.message
                );
                writable = false;
            }

            return writable;
        }

        // Return true if the file exists
        public bool exists (Cancellable? cancellable = null) {
            return this.file.query_exists (cancellable); /* May block */
        }

        private void file_changed () {
            if (mount != null) {
                mount.unmounted.disconnect (unmounted_cb);
                mount = null;
            }

            try {
                mount = file.find_enclosing_mount ();
                mount.unmounted.connect (unmounted_cb);
            } catch (Error e) {
                debug ("Could not find mount location");
                return;
            }
            mounted = true;
        }

        public void show_outline (bool show) {
            if (show && outline == null) {
                switch (mime_type) {
                    case "text/x-vala":
                        outline = new ValaSymbolOutline (this);
                        break;
                    case "text/x-csrc":
                    case "text/x-chdr":
                    case "text/x-c++src":
                    case "text/x-c++hdr":
                        outline = new CtagsSymbolOutline (this);
                        break;
                }

                if (outline != null) {
                    outline_widget_pane.pack2 (outline.get_widget (), false, false);
                    var position = int.max (outline_widget_pane.get_allocated_width () * 4 / 5, 100);
                    outline_widget_pane.set_position (position);
                    outline.parse_symbols ();
                }
            } else if (!show && outline != null) {
                outline_widget_pane.get_child2 ().destroy ();
                outline = null;
            }
        }

        private void unmounted_cb () {
            warning ("Folder containing the file was unmounted");
            mounted = false;
        }

        public void goto (int line) {
            var text = source_view;
            Gtk.TextIter iter;
            text.buffer.get_iter_at_line (out iter, line - 1);
            text.buffer.place_cursor (iter);
            text.scroll_to_iter (iter, 0.0, true, 0.5, 0.5);
        }
    }
}
