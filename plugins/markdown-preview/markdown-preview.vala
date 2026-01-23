// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2026 Elementary Code Contributors
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

public class Code.Plugins.MarkdownPreview : Peas.ExtensionBase, Scratch.Services.ActivatablePlugin {
    Scratch.Services.Interface plugins;
    Scratch.Widgets.SourceView? current_source = null;
    Scratch.HeaderBar? toolbar = null;
    Gtk.ToggleButton? preview_button = null;
    
    // Store preview state per document
    private Gee.HashMap<Scratch.Services.Document, PreviewState> preview_states;
    
    public Object object { owned get; set construct; }

    public void update_state () {}

    private class PreviewState {
        public WebKit.WebView web_view;
        public Gtk.ScrolledWindow scrolled_window;
        public Gtk.Paned? paned = null;
        public Gtk.ScrolledWindow? original_scroll = null;
        public bool visible = false;
        
        public PreviewState () {
            web_view = new WebKit.WebView ();
            web_view.expand = true;
            
            scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.add (web_view);
            scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            
            // Handle Ctrl+Scroll for zooming on the WebView directly
            web_view.scroll_event.connect ((event) => {
                if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    double zoom = web_view.zoom_level;
                    
                    if (event.direction == Gdk.ScrollDirection.UP) {
                        zoom += 0.1;
                    } else if (event.direction == Gdk.ScrollDirection.DOWN) {
                        zoom -= 0.1;
                    } else if (event.direction == Gdk.ScrollDirection.SMOOTH) {
                        double dx, dy;
                        event.get_scroll_deltas (out dx, out dy);
                        // In smooth scrolling, dy is negative for scrolling up (zooming in)
                        // and positive for scrolling down (zooming out)
                        if (dy < 0) zoom += 0.1;
                        else if (dy > 0) zoom -= 0.1;
                    }
                    
                    // Clamp zoom level logic if needed, but WebKit handles reasonable limits.
                    // Just ensure it doesn't go negative or too small.
                    if (zoom < 0.1) zoom = 0.1;
                    
                    web_view.zoom_level = zoom;
                    return true; // Stop propagation (prevent scrolling)
                }
                return false;
            });
        }
    }

    public void activate () {
        plugins = (Scratch.Services.Interface) object;
        preview_states = new Gee.HashMap<Scratch.Services.Document, PreviewState> ();
        
        // Create toggle button for toolbar
        preview_button = new Gtk.ToggleButton ();
        preview_button.image = new Gtk.Image.from_icon_name ("view-paged-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
        preview_button.tooltip_text = "Toggle Markdown Preview (Ctrl+Shift+M)";
        preview_button.toggled.connect (on_preview_toggled);
        preview_button.no_show_all = true;
        
        // Hook into toolbar
        plugins.hook_toolbar.connect ((t) => {
            toolbar = t;
        });
        
        // Hook into document changes
        plugins.hook_document.connect ((doc) => {
            if (current_source != null) {
                current_source.notify["language"].disconnect (on_language_changed);
            }

            current_source = doc.source_view;
            on_language_changed ();
            
            current_source.notify["language"].connect (on_language_changed);
            
            // Update preview button state based on this document's preview state
            var state = preview_states.get (doc);
            if (state != null) {
                preview_button.active = state.visible;
            } else {
                preview_button.active = false;
            }
        });
    }

    private void on_language_changed () {
        if (toolbar == null || current_source == null) {
            return;
        }
        
        var lang = current_source.language;
        bool is_markdown = (lang != null && lang.id == "markdown");
        
        // Show/hide preview button based on file type
        if (is_markdown) {
            if (preview_button.parent == null) {
                toolbar.pack_end (preview_button);
            }
            preview_button.show ();
        } else {
            preview_button.hide ();
            
            // Hide preview if visible for non-markdown files
            if (preview_button.active) {
                preview_button.active = false;
            }
        }
    }

    private void on_preview_toggled () {
        if (current_source == null) {
            return;
        }
        
        // Get the current document
        var doc = get_document_for_source (current_source);
        if (doc == null) {
            return;
        }
        
        if (preview_button.active) {
            show_preview (doc);
        } else {
            hide_preview (doc);
        }
    }

    private Scratch.Services.Document? get_document_for_source (Scratch.Widgets.SourceView source) {
        // The source view's parent chain: SourceView -> ScrolledWindow -> Grid -> Paned -> Grid -> Stack -> Document
        var widget = source.parent;
        while (widget != null) {
            if (widget is Scratch.Services.Document) {
                return (Scratch.Services.Document) widget;
            }
            widget = widget.parent;
        }
        return null;
    }

    private void show_preview (Scratch.Services.Document doc) {
        var state = preview_states.get (doc);
        if (state == null) {
            state = new PreviewState ();
            preview_states.set (doc, state);
        }
        
        if (state.visible) {
            return; // Already showing
        }
        
        // Find the scrolled window containing the source view
        var scroll = doc.source_view.parent as Gtk.ScrolledWindow;
        if (scroll == null) {
            warning ("Could not find scroll window for source view");
            return;
        }
        
        // Get the parent of the scroll window (should be a Grid)
        var scroll_parent = scroll.parent;
        if (scroll_parent == null) {
            warning ("Could not find parent of scroll window");
            return;
        }
        
        // Store reference to original scroll window
        state.original_scroll = scroll;
        
        // Create a paned widget to hold both the source view and preview
        state.paned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        
        // Remove the scroll window from its parent
        scroll_parent.remove (scroll);
        
        // Add both to the paned widget
        state.paned.pack1 (scroll, true, false);
        state.paned.pack2 (state.scrolled_window, true, false);
        
        // Set initial position to 50/50 split
        state.paned.position = scroll.get_allocated_width () / 2;
        
        // Add the paned widget back to the parent
        if (scroll_parent is Gtk.Grid) {
            ((Gtk.Grid) scroll_parent).add (state.paned);
        } else if (scroll_parent is Gtk.Box) {
            ((Gtk.Box) scroll_parent).pack_start (state.paned, true, true, 0);
        }
        
        state.paned.show_all ();
        state.visible = true;
        
        // Update the preview content
        update_preview (doc, state);
        
        // Connect to buffer changes for live updates
        doc.source_view.buffer.changed.connect (() => {
            on_text_changed (doc);
        });
    }

    private void hide_preview (Scratch.Services.Document doc) {
        var state = preview_states.get (doc);
        if (state == null || !state.visible) {
            return;
        }
        
        if (state.paned == null || state.original_scroll == null) {
            return;
        }
        
        // Get the parent that contains the paned widget
        var paned_parent = state.paned.parent;
        if (paned_parent == null) {
            return;
        }
        
        // Remove the scroll window from the paned
        state.paned.remove (state.original_scroll);
        
        // Remove the paned from its parent
        paned_parent.remove (state.paned);
        
        // Add the scroll window back to its original parent
        if (paned_parent is Gtk.Grid) {
            ((Gtk.Grid) paned_parent).add (state.original_scroll);
        } else if (paned_parent is Gtk.Box) {
            ((Gtk.Box) paned_parent).pack_start (state.original_scroll, true, true, 0);
        }
        
        state.visible = false;
        state.paned = null;
    }

    private uint update_timeout_id = 0;
    private Scratch.Services.Document? pending_update_doc = null;
    
    private void on_text_changed (Scratch.Services.Document doc) {
        // Debounce updates - wait 500ms after typing stops
        if (update_timeout_id > 0) {
            Source.remove (update_timeout_id);
        }
        
        pending_update_doc = doc;
        update_timeout_id = Timeout.add (500, () => {
            if (pending_update_doc != null) {
                var state = preview_states.get (pending_update_doc);
                if (state != null && state.visible) {
                    update_preview (pending_update_doc, state);
                }
            }
            update_timeout_id = 0;
            pending_update_doc = null;
            return false;
        });
    }

    private void update_preview (Scratch.Services.Document doc, PreviewState state) {
        var buffer = doc.source_view.buffer;
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        var markdown_text = buffer.get_text (start, end, false);
        
        var html = markdown_to_html (markdown_text);
        state.web_view.load_html (html, null);
    }

    private string markdown_to_html (string markdown) {
        var html = new StringBuilder ();
        
        // Add HTML header with GitHub-flavored styling
        html.append ("""
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            font-size: 16px;
            line-height: 1.6;
            color: #24292e;
            background-color: #ffffff;
            padding: 20px;
            margin: 0;
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }
        h1 { font-size: 2em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: #6a737d; }
        p { margin-top: 0; margin-bottom: 16px; }
        a { color: #0366d6; text-decoration: none; }
        a:hover { text-decoration: underline; }
        code {
            background-color: rgba(27,31,35,0.05);
            border-radius: 3px;
            font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
            font-size: 85%;
            margin: 0;
            padding: 0.2em 0.4em;
        }
        pre {
            background-color: #f6f8fa;
            border-radius: 3px;
            font-size: 85%;
            line-height: 1.45;
            overflow: auto;
            padding: 16px;
            margin: 0 0 16px 0;
        }
        pre code {
            background-color: transparent;
            border: 0;
            display: inline;
            line-height: inherit;
            margin: 0;
            overflow: visible;
            padding: 0;
            word-wrap: normal;
        }
        blockquote {
            border-left: 0.25em solid #dfe2e5;
            color: #6a737d;
            padding: 0 1em;
            margin: 0 0 16px 0;
        }
        ul, ol {
            margin-top: 0;
            margin-bottom: 16px;
            padding-left: 2em;
        }
        li + li {
            margin-top: 0.25em;
        }
        table {
            border-collapse: collapse;
            border-spacing: 0;
            margin-bottom: 16px;
        }
        table th, table td {
            border: 1px solid #dfe2e5;
            padding: 6px 13px;
        }
        table th {
            background-color: #f6f8fa;
            font-weight: 600;
        }
        table tr {
            background-color: #ffffff;
            border-top: 1px solid #c6cbd1;
        }
        table tr:nth-child(2n) {
            background-color: #f6f8fa;
        }
        img {
            max-width: 100%;
            box-sizing: content-box;
        }
        hr {
            height: 0.25em;
            padding: 0;
            margin: 24px 0;
            background-color: #e1e4e8;
            border: 0;
        }
        strong { font-weight: 600; }
        em { font-style: italic; }
    </style>
</head>
<body>
""");
        
        // Simple markdown parsing
        var lines = markdown.split ("\n");
        bool in_code_block = false;
        string list_type = ""; // "ul" or "ol"
        string code_lang = "";
        
        foreach (var line in lines) {
            var trimmed = line.strip ();
            
            // Code blocks
            if (trimmed.has_prefix ("```")) {
                if (in_code_block) {
                    html.append ("</code></pre>\n");
                    in_code_block = false;
                    code_lang = "";
                } else {
                    // Close list if open
                    if (list_type != "") {
                        html.append ("</" + list_type + ">\n");
                        list_type = "";
                    }
                    
                    code_lang = trimmed.substring (3).strip ();
                    html.append ("<pre><code>");
                    in_code_block = true;
                }
                continue;
            }
            
            if (in_code_block) {
                html.append (GLib.Markup.escape_text (line));
                html.append ("\n");
                continue;
            }
            
            // Headers
            if (trimmed.has_prefix ("#")) {
                if (list_type != "") {
                    html.append ("</" + list_type + ">\n");
                    list_type = "";
                }
                
                if (trimmed.has_prefix ("######")) {
                    html.append ("<h6>").append (process_inline (trimmed.substring (6).strip ())).append ("</h6>\n");
                } else if (trimmed.has_prefix ("#####")) {
                    html.append ("<h5>").append (process_inline (trimmed.substring (5).strip ())).append ("</h5>\n");
                } else if (trimmed.has_prefix ("####")) {
                    html.append ("<h4>").append (process_inline (trimmed.substring (4).strip ())).append ("</h4>\n");
                } else if (trimmed.has_prefix ("###")) {
                    html.append ("<h3>").append (process_inline (trimmed.substring (3).strip ())).append ("</h3>\n");
                } else if (trimmed.has_prefix ("##")) {
                    html.append ("<h2>").append (process_inline (trimmed.substring (2).strip ())).append ("</h2>\n");
                } else if (trimmed.has_prefix ("#")) {
                    html.append ("<h1>").append (process_inline (trimmed.substring (1).strip ())).append ("</h1>\n");
                }
            }
            // Horizontal rule
            else if (trimmed == "---" || trimmed == "***" || trimmed == "___") {
                if (list_type != "") {
                    html.append ("</" + list_type + ">\n");
                    list_type = "";
                }
                html.append ("<hr>\n");
            }
            // Blockquote
            else if (trimmed.has_prefix (">")) {
                if (list_type != "") {
                    html.append ("</" + list_type + ">\n");
                    list_type = "";
                }
                html.append ("<blockquote><p>").append (process_inline (trimmed.substring (1).strip ())).append ("</p></blockquote>\n");
            }
            // Unordered list
            else if (trimmed.has_prefix ("* ") || trimmed.has_prefix ("- ") || trimmed.has_prefix ("+ ")) {
                if (list_type == "ol") {
                    html.append ("</ol>\n");
                    list_type = "";
                }
                if (list_type == "") {
                    html.append ("<ul>\n");
                    list_type = "ul";
                }
                html.append ("<li>").append (process_inline (trimmed.substring (2))).append ("</li>\n");
            }
            // Ordered list
            else if (trimmed.length > 2 && trimmed[0].isdigit () && trimmed[1] == '.' && trimmed[2] == ' ') {
                if (list_type == "ul") {
                    html.append ("</ul>\n");
                    list_type = "";
                }
                if (list_type == "") {
                    html.append ("<ol>\n");
                    list_type = "ol";
                }
                html.append ("<li>").append (process_inline (trimmed.substring (3))).append ("</li>\n");
            }
            // Empty line
            else if (trimmed == "") {
                if (list_type != "") {
                    html.append ("</" + list_type + ">\n");
                    list_type = "";
                }
                html.append ("<br>\n");
            }
            // Regular paragraph
            else {
                if (list_type != "") {
                    html.append ("</" + list_type + ">\n");
                    list_type = "";
                }
                html.append ("<p>").append (process_inline (line)).append ("</p>\n");
            }
        }
        
        if (list_type != "") {
            html.append ("</" + list_type + ">\n");
        }
        
        html.append ("</body></html>");
        return html.str;
    }

    private string process_inline (string text) {
        var result = GLib.Markup.escape_text (text);
        
        // Bold **text** or __text__
        try {
            var bold_regex = new Regex ("\\*\\*(.+?)\\*\\*");
            result = bold_regex.replace (result, -1, 0, "<strong>\\1</strong>");
            
            var bold_regex2 = new Regex ("__(.+?)__");
            result = bold_regex2.replace (result, -1, 0, "<strong>\\1</strong>");
            
            // Italic *text* or _text_
            var italic_regex = new Regex ("\\*(.+?)\\*");
            result = italic_regex.replace (result, -1, 0, "<em>\\1</em>");
            
            var italic_regex2 = new Regex ("_(.+?)_");
            result = italic_regex2.replace (result, -1, 0, "<em>\\1</em>");
            
            // Inline code `code`
            var code_regex = new Regex ("`(.+?)`");
            result = code_regex.replace (result, -1, 0, "<code>\\1</code>");
            
            // Links [text](url)
            var link_regex = new Regex ("\\[(.+?)\\]\\((.+?)\\)");
            result = link_regex.replace (result, -1, 0, "<a href=\"\\2\">\\1</a>");
            
            // Images ![alt](url)
            var img_regex = new Regex ("!\\[(.+?)\\]\\((.+?)\\)");
            result = img_regex.replace (result, -1, 0, "<img src=\"\\2\" alt=\"\\1\">");
        } catch (RegexError e) {
            warning ("Regex error: %s", e.message);
        }
        
        return result;
    }

    public void deactivate () {
        // Clean up all preview states
        foreach (var doc in preview_states.keys) {
            if (preview_states.get (doc).visible) {
                hide_preview (doc);
            }
        }
        preview_states.clear ();
        
        if (toolbar != null && preview_button != null && preview_button.parent != null) {
            toolbar.remove (preview_button);
        }
        
        if (update_timeout_id > 0) {
            Source.remove (update_timeout_id);
            update_timeout_id = 0;
        }
    }
}

[ModuleInit]
public void peas_register_types (TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Scratch.Services.ActivatablePlugin),
                                     typeof (Code.Plugins.MarkdownPreview));
}
