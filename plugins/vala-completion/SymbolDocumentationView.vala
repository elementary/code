/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class SymbolDocumentationView : Gtk.Stack {
    private const string VALADOC_SYMBOL_DOCUMENTATION = "http://valadoc.org/%s/%s";
    private const string JAVASCRIPT_STRING = """
        document.body.style.padding = 0;
        document.getElementById('sidebar').style.display = 'None';
        var navs = document.getElementsByTagName('nav');
        if (navs.length) {
            navs[0].style.display = 'None';
        }
        
        var footers = document.getElementsByTagName('footer');
        if (footers.length) {
            footers[0].style.display = 'None';
        }

        var wrapper = document.getElementById('content-wrapper');
        wrapper.style.width = 100;
        wrapper.style.marginLeft = 0;

        var content = document.getElementById('content');
        content.style.width = 100;
        content.style.margin = 0;
    """;

    private Vala.Symbol _symbol;
    public Vala.Symbol symbol { 
        get {
            return _symbol;
        }

        set {
            _symbol = value;
            update_web_view ();
        }
    }

    private WebKit.WebView web_view;
    private Gtk.LinkButton link_button;
    private Gtk.Grid spinner_grid;

    construct {
        var settings = new WebKit.Settings ();
        settings.enable_javascript = true;

        var doc_grid = new Gtk.Grid ();

        web_view = new WebKit.WebView ();
        web_view.expand = true;
        web_view.settings = settings;
        web_view.load_changed.connect ((load) => {
            if (load == WebKit.LoadEvent.FINISHED) {
                inject_javascript ();
                visible_child = doc_grid;
            }
        });

        link_button = new Gtk.LinkButton.with_label ("http://www.valadoc.org", _("Open in Web Browser"));
        link_button.halign = Gtk.Align.END;
        link_button.hexpand = false;
        link_button.margin = 6;

        doc_grid.attach (web_view, 0, 0, 1, 1);
        doc_grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1, 1, 1);
        doc_grid.attach (link_button, 0, 2, 1, 1);
        doc_grid.show_all ();

        var spinner = new Gtk.Spinner ();
        spinner.halign = Gtk.Align.CENTER;
        spinner.valign = Gtk.Align.CENTER;
        spinner.start ();

        spinner_grid = new Gtk.Grid ();
        spinner_grid.halign = Gtk.Align.CENTER;
        spinner_grid.valign = Gtk.Align.CENTER;
        spinner_grid.add (spinner);
        spinner_grid.show_all ();

        add (doc_grid);
        add (spinner_grid);
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        minimum_width = 100;
        natural_width = 500;
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        minimum_height = 200;
        natural_height = 400;
    }

    private void update_web_view () {
        string? uri = get_symbol_valadoc_uri (symbol);
        if (uri != null) {
            link_button.uri = uri;
            web_view.load_uri (uri);
            visible_child = spinner_grid;
        }
    }

    private void inject_javascript () {
        web_view.run_javascript.begin (JAVASCRIPT_STRING, null);
    }

    private static string? get_symbol_valadoc_uri (Vala.Symbol symbol) {
        var source_reference = symbol.source_reference;
        if (source_reference != null && source_reference.file != null) {
            string basename = Path.get_basename (source_reference.file.filename);
            string package = basename.replace (".vapi", "");
            return VALADOC_SYMBOL_DOCUMENTATION.printf (package, symbol.get_full_name ());
        }

        return null;
    }
}