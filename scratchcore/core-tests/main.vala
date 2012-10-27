using Scratch;

public int main(string[] args)
{
    Test.init(ref args);
    Gtk.init(ref args);
    
    Scratch.saved_state = new Scratch.SavedState ();
    Scratch.settings = new Scratch.Settings ();
    Scratch.services = new Scratch.ServicesSettings ();

    Test.add_func("/scratch/core/search_manager", () => {
        var search = new Scratch.Services.SearchManager (null);
        var sourceview = new Scratch.Widgets.SourceView ();
        search.set_text_view (sourceview);
        
        assert(sourceview.buffer.cursor_position == 0);
        
        sourceview.buffer.text = "elementary scratch test Euclide ele";
        
        search.set_search_string ("e");
        search.search ();
        assert(sourceview.buffer.cursor_position == 0);
        search.search_next ();
        assert(sourceview.buffer.cursor_position == 2);
        search.search_previous ();
        assert(sourceview.buffer.cursor_position == 0);
        
        search.set_search_string ("el");
        search.search ();
        assert(sourceview.buffer.cursor_position == 0);
        search.search_next ();
        assert(sourceview.buffer.cursor_position == "elementary scratch test euclide ".length);
        
        search.set_search_string ("s");
        search.search ();
        assert(sourceview.buffer.cursor_position == "elementary ".length);
        
        /* Case sensitive */
        search.set_search_string ("EST");
        search.search ();
        assert(sourceview.buffer.cursor_position == "elementary scratch test".length - 3);
        search.set_search_string ("Eu");
        print ("%d", sourceview.buffer.cursor_position);
        search.search ();
        assert(sourceview.buffer.cursor_position == "elementary scratch test E".length - 1);
    });
    
    Test.add_func("/scratch/core/source_view", () => {
        var sourceview = new Scratch.Widgets.SourceView ();
        
        assert (sourceview.buffer.cursor_position == 0);
        
        sourceview.buffer.text = "elementary scratch\ntest Euclide ele";
        
        sourceview.go_to_line (2);
        assert (sourceview.buffer.cursor_position == "elementary scratch\n".length);
        sourceview.go_to_line (1);
        assert (sourceview.buffer.cursor_position == 0);
        
        var lang = sourceview.change_syntax_highlight_for_filename ("immaginary.vala");
        var blang = sourceview.buffer.get_language ();
        assert (lang.get_id () == blang.get_id ());
        
    });
    
    Test.add_func ("/scratch/core/template_manager", () => {
        /* cleanup */
        try {
            Process.spawn_sync ("/", {"rm", Environment.get_tmp_dir () + "/scratch-tpl", "-Rf"}, null, SpawnFlags.SEARCH_PATH, null);
        } catch (SpawnError e) {
            warning (e.message);
        }
        File file = File.new_for_path ("/tmp/scratch-tpl/");
        bool is_dir, exists;
        Scratch.Template.info_directory (file, out is_dir, out exists);
        assert (exists == false);
        assert (is_dir == false);
        
        file = File.new_for_path ("../../../tests/template_test/");
        Scratch.Template.info_directory (file, out is_dir, out exists);
        assert (exists == true);
        assert (is_dir == true);
        
        file = File.new_for_path ("../../../tests/template_test/README");
        Scratch.Template.info_directory (file, out is_dir, out exists);
        assert (exists == true);
        assert (is_dir == false);
        
        file = File.new_for_path ("../../../tests/template_test/");
        List<FileInfo> files;
        List<File> dirs;
        Scratch.Template.enumerate_directory (file, out files, out dirs);
        assert (dirs.length () == 1);
        assert (files.length () == 1);
        debug(files.nth_data (0).get_name ());
        assert (files.nth_data (0).get_name () == "README");

        var variables = new Gee.HashMap<string, string> ();
        variables ["NAME"] = "Demo App";
        Scratch.Template.configure_template ("../../../tests/template_test/", "/tmp/scratch-tpl/", variables);
    });
    
    Test.run();
    return 0;
}
