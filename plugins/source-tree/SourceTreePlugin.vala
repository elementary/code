// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Tom Beckmann <tomjonabc@gmail.com>
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

public const string NAME = N_("Source Tree");
public const string DESCRIPTION = N_("Have a look at your sources organized in a nice tree");

const bool HIDE_TOOLBAR = true;
const bool DARK_THEME = true;

Scratch.Services.Interface scratch_interface;

public class Folder : Granite.Widgets.SourceList.ExpandableItem
{
	public File file { get; construct set; }
	bool loaded = false;

	public Folder (File dir)
	{
		file = dir;
		name = dir.get_basename ();
		selectable = false;
		
		//need to add one item to make the folder appear
		add (new Granite.Widgets.SourceList.Item (_("Loading...")));
		
		toggled.connect (() => {
			if (!expanded || loaded)
				return;
			
			loaded = true;
			
			load ();
			foreach (var child in children) {
				if (!(child is Document) && !(child is Folder))
					remove (child);
			}
		});
	}

	const string ATTRIBUTES = FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE + 
		"," + FileAttribute.STANDARD_ICON;
	public void load ()
	{
		try {
			var enumerator = file.enumerate_children (ATTRIBUTES, FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
			FileInfo? file_info = null;
			
			while ((file_info = enumerator.next_file ()) != null) {
				var file_name = file_info.get_name ();
				var file_type = file_info.get_file_type ();
				
				if (file_type == FileType.REGULAR && !file_name.has_suffix ("~") && !file_name.has_prefix (".")) {
					add (new Document (file.get_child (file_name), file_info.get_icon ()));
				} else if (file_type == FileType.DIRECTORY && !file_name.has_prefix (".")) {
					add (new Folder (file.get_child (file_name)));
				}
			}
		} catch (Error e) { warning (e.message); }
	}
}

public class Document : Granite.Widgets.SourceList.Item
{
	public Scratch.Services.Document? doc { get; private set; }
	public File file { get; construct set; }

	public Document (File file, Icon icon)
	{
		Object (file: file, icon: icon);
		
		name = file.get_basename ();
		
		action_activated.connect (() => {
			if (parent == null)
				return;
				
            scratch_interface.close_document (doc);
			parent.remove (this);
		});
	}

	public Document.scratch (Scratch.Services.Document _doc)
	{
		Icon icon = new FileIcon (_doc.file);
		try {
			icon = _doc.file.query_info (FileAttribute.STANDARD_ICON, 0).get_icon ();
		} catch (Error e) { warning (e.message); }
		this (_doc.file, icon);
		doc = _doc;
		try {
			activatable = Gtk.IconTheme.get_default ().lookup_by_gicon (new ThemedIcon ("window-close-symbolic"), 16, 0).load_symbolic ({1, 1, 1, 1});
		} catch (Error e) { warning (e.message); }		
	}
}

public class Bookmark : Granite.Widgets.SourceList.Item
{
	public Scratch.Services.Document doc { get; construct set; }
	public Gtk.TextIter iter { get; construct set; }

	public Bookmark (Scratch.Services.Document doc, Gtk.TextIter iter)
	{
		Object(name: doc.get_basename () + ":" + (iter.get_line () + 1).to_string (),
			doc: doc, iter: iter, icon: new ThemedIcon ("tag-new"));
		try {
			activatable = Gtk.IconTheme.get_default ().lookup_by_gicon (new ThemedIcon ("window-close-symbolic"), 16, 0).load_symbolic ({1, 1, 1, 1});
		} catch (Error e) { warning (e.message); }

		action_activated.connect (() => {
			if (parent == null)
				return;
			
			parent.remove (this);
		});
	}
}

namespace Scratch.Plugins {
    public class SourceTreePlugin : Peas.ExtensionBase, Peas.Activatable {
        Scratch.Services.Interface plugins;
        public Object object { owned get; construct; }
        
        Gtk.ToolButton bookmark_tool_button;
		Granite.Widgets.SourceList view;
		Granite.Widgets.SourceList.ExpandableItem category_files;
		Granite.Widgets.SourceList.ExpandableItem category_project;
		Granite.Widgets.SourceList.ExpandableItem category_bookmarks;

		File? root = null;

		bool my_select = false;

        public void activate () {
			if (DARK_THEME)
				Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;

            plugins = (Scratch.Services.Interface) object;
            plugins.hook_notebook_sidebar.connect (on_hook_sidebar);
			plugins.hook_document.connect (on_hook_document);
			plugins.hook_toolbar.connect ((toolbar) => {
				this.bookmark_tool_button = new Gtk.ToolButton (new Gtk.Image.from_icon_name ("bookmark-new", Gtk.IconSize.LARGE_TOOLBAR), _("Bookmark"));
				bookmark_tool_button.show_all ();
				bookmark_tool_button.clicked.connect (() => add_bookmark ());
				toolbar.insert (bookmark_tool_button, toolbar.get_item_index (toolbar.find_button) + 1);
			});
			plugins.hook_split_view.connect ((view) => {
			    this.bookmark_tool_button.visible = ! view.is_empty ();
                this.bookmark_tool_button.no_show_all = view.is_empty ();
                view.welcome_shown.connect (() => {
                    this.bookmark_tool_button.visible = false;
                    this.bookmark_tool_button.no_show_all = true;
                });
                view.welcome_hidden.connect (() => {
                    this.bookmark_tool_button.visible = true;
                    this.bookmark_tool_button.no_show_all = false;
                });
			});
			
			scratch_interface = ((Scratch.Services.Interface)object);
        }

        public void deactivate () {
            if (view != null)
                view.destroy();
        }

        public void update_state () {
        }

        void on_hook_sidebar (Gtk.Notebook notebook) {
            if (view != null)
                return;

			view = new Granite.Widgets.SourceList ();
			view.set_sort_func ((a, b) => {
				if (a is Folder && b is Folder)
					return a.name.collate (b.name);
				if (a is Folder)
					return -1;
				if (b is Folder)
					return 1;

				return a.parent == view.root && a.name == "Bookmarks" ? 1 : a.name.collate (b.name);
			});

			view.get_style_context ().add_class ("sidebar");
			category_files = new Granite.Widgets.SourceList.ExpandableItem (_("Files"));
			category_project = new Granite.Widgets.SourceList.ExpandableItem (_("Project"));
			category_bookmarks = new Granite.Widgets.SourceList.ExpandableItem (_("Bookmarks"));
			view.root.add (category_files);
			view.root.add (category_project);
			view.root.add (category_bookmarks);
			view.show_all ();

			view.item_selected.connect ((new_current) => {
				if (my_select) return;

				if (new_current is Bookmark) {
					var bookmark = new_current as Bookmark;
					((Scratch.Services.Interface)object).open_file (bookmark.doc.file);
					var text = bookmark.doc.source_view;
					text.buffer.place_cursor (bookmark.iter);
					text.scroll_to_iter (bookmark.iter, 0.0, true, 0.5, 0.5);
					return;
				}

				var doc = new_current as Document;
				((Scratch.Services.Interface)object).open_file (doc.file);
			});

			notebook.append_page (view, new Gtk.Label (_("Source Tree")));
        }

		void on_hook_document (Scratch.Services.Document doc) {
			(doc.get_parent () as Gtk.Notebook).set_show_tabs (!HIDE_TOOLBAR);
            
			foreach (var d in category_files.children) {
				if ((d as Document).file == doc.file) {
					view.selected = d;
					return;
				}
			}

			if (doc.file == null) {
				doc.doc_saved.connect (wait_for_save);
				return;
			}

			add_doc (doc);
		}

		void wait_for_save (Scratch.Services.Document doc) {
			doc.doc_saved.disconnect (wait_for_save);
			add_doc (doc);
		}

		void add_doc (Scratch.Services.Document doc) {
			var item = new Document.scratch (doc);
			category_files.add (item);
			my_select = true;
			view.selected = item;
			my_select = false;

			var new_root = detect_project (doc.file);
			if (root == null || root.get_path () != new_root.get_path ()) {
				root = new_root;
				category_project.clear ();
				category_project.add (new Folder (root));
			}
		}

		void add_bookmark () {
			var doc = (view.selected as Document).doc as Scratch.Services.Document;
			var buffer = doc.source_view.buffer;
			Gtk.TextIter iter;
			buffer.get_iter_at_offset (out iter, buffer.cursor_position);

			var bookmark = new Bookmark (doc, iter);
			category_bookmarks.add (bookmark);
			category_bookmarks.expand_all ();
		}

		const string [] vcss = {".bzr", ".git", ".hg"};
		File? detect_project (File opened)	{
			//go up looking for a vcs indicating folder
			var dir = opened;
			while ((dir = dir.get_parent ()) != null) {
				foreach (var vcs in vcss) {
					if (dir.get_child (vcs).query_exists ()) {
						return dir;
					}
				}
			}

			//checking for src, might not be under version control yet
			dir = opened.get_parent ();
			if (dir.get_basename () == "src") {
				dir = dir.get_parent ();
			} else if (dir.get_parent ().get_basename () == "src") {
				dir = dir.get_parent ().get_parent ();
			}
			
			return dir;
		}
	}
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
  var objmodule = module as Peas.ObjectModule;
  objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Scratch.Plugins.SourceTreePlugin));
}
