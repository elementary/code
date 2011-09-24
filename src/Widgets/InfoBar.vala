// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Mario Guerriero <mefrio.g@gmail.com> 
  This program is free software: you can redistribute it and/or modify it	
  under the terms of the GNU Lesser General Public License version 3, as
  published	by the Free Software Foundation.
	
  This program is distributed in the hope that it will be useful, but	
  WITHOUT ANY WARRANTY; without even the implied warranties of	
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR	
  PURPOSE.  See the GNU General Public License for more details.
	
  You should have received a copy of the GNU General Public License along	
  with this program.  If not, see <http://www.gnu.org/licenses>
  
  END LICENSE	
***/

using Gtk;

using Scratch;

namespace Scratch.Widgets {
	
	public class ScratchInfoBar: Gtk.Overlay {
		
		private Widget caller;
		
		private InfoBar infobar;
		private Button status;
		
		public ScratchInfoBar (Widget caller) {
			
			this.caller = caller;
			caller.show_all ();
			
			add (caller);
			
			this.infobar = new InfoBar ();
			this.status = new Button ();
			
			infobar.expand = false;
            infobar.halign = Align.START;
			infobar.valign = Align.END;
			
			infobar.add_action_widget (status, 0);	
			infobar.response.connect (on_response);

			add_overlay (infobar);
			
			show_all ();
			
			infobar.hide ();
		}
		
		private void on_response (int response) {
			if (response == 0) 
				this.infobar.hide ();
		}
		
		public void set_info (string info) {
			status.set_label (info);
			this.show ();	
		}
		
		public void show () {
			infobar.show ();
		}
		
		public void hide () {
			infobar.hide ();
		}
	
	} 
	
}
