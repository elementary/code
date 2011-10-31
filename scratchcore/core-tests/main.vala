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
        var sourceview = new Scratch.Widgets.SourceView (null);
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
        assert(search.case_sensitive == false);
        search.set_search_string ("E");
        search.search ();
        assert(sourceview.buffer.cursor_position == "elementary scratch t".length);
        search.case_sensitive = true;
        search.set_search_string ("E");
        search.search ();
        assert(sourceview.buffer.cursor_position == "elementary scratch test ".length);
    });
    
    Test.add_func("/scratch/core/source_view", () => {
        var sourceview = new Scratch.Widgets.SourceView (null);
        
        assert (sourceview.buffer.cursor_position == 0);
        
        sourceview.buffer.text = "elementary scratch\ntest Euclide ele";
        
        sourceview.go_to_line (1);
        assert (sourceview.buffer.cursor_position == "elementary scratch\n".length);
        
        var lang = sourceview.change_syntax_highlight_for_filename ("immaginary.vala");
        var blang = sourceview.buffer.get_language ();
        assert (lang.get_id () == blang.get_id ());
        
    });
    
    Test.run();
    return 0;
}
