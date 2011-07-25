/***
BEGIN LICENSE
Copyright (C) 2011 Avi Romanoff <aviromanoff@gmail.com>
This program is free software: you can redistribute it and/or modify it 
under the terms of the GNU Lesser General Public License version 2.1, as published 
by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but 
WITHOUT ANY WARRANTY; without even the implied warranties of 
MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR 
PURPOSE.\  See the GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License along 
with this program.  If not, see <http://www.gnu.org/licenses/>.
END LICENSE
***/

using Gtk;
using Pango;
using GtkSource;

public class Tab : ScrolledWindow {

	public TextView text_view;
	public Label label;
	public string filename;
	
	public Tab() {
		
		var s = new View ();
		
		this.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		this.text_view = new TextView ();
		this.add (text_view);
		this.label = new Label ("New file");
		this.filename = null;
		this.show_all();

	}

}

public class ScratchNotebook : Notebook {

	public int add_tab() {
		var new_tab = new Tab();
		this.set_tab_reorderable (new_tab, true);
		return this.append_page (new_tab, null);
	}

	public ScratchNotebook() {
		this.set_scrollable (true);
	}


}
