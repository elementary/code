/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Giulio Collura <random.cpp@gmail.com> 
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


using Gtk;
using Gdk;

using Granite;
using Granite.Services;

namespace Scratch {

    public class Scratch : Granite.Application {
    	
        private MainWindow window = null;

        public static SavedState saved_state {get; private set; default = null;}
        public static Settings settings {get; private set; default = null;}
        public static ServicesSettings services {get; private set; default = null;}
        
        construct {
        
            build_data_dir = Constants.DATADIR;
			build_pkg_data_dir = Constants.PKGDATADIR;
			build_release_name = Constants.RELEASE_NAME;
			build_version = Constants.VERSION;
			build_version_info = Constants.VERSION_INFO;
			
            program_name = "Scratch";
		    exec_name = "scratch";
		    app_copyright = "GPLv3";
		    app_icon = "text-editor";
		    app_launcher = "scratch.desktop";
            application_id = "net.launchpad.scratch";
		    main_url = "https://launchpad.net/scratch";
		    bug_url = "https://bugs.launchpad.net/scratch";
		    help_url = "https://answers.launchpad.net/scratch";
		    translate_url = "https://translations.launchpad.net/scratch";
		    
		    about_authors = {"Mario Guerriero <mefrio.g@gmail.com>",
                             "Giulio Collura <random.cpp@gmail.com>",
                             "Gabriele Coletta <gdmg92@gmail.com>"
                             };
        					    
        	//about_documenters = {"",""};
		about_artists = {"Harvey Cabaguio 'BassUltra' <harveycabaguio@gmail.com>"};
		about_translators = "Launchpad Translators";
         
		
		}

        public Scratch () {
			
			Logger.initialize ("Scratch");
			Logger.DisplayLevel = LogLevel.DEBUG;
            
            set_flags (ApplicationFlags.HANDLES_OPEN);

            saved_state = new SavedState ();
            settings = new Settings ();
            services = new ServicesSettings ();

        }

        protected override void open (File[] files, string hint) {

            if (get_windows () == null) {
                window = new MainWindow ();
                window.set_application (this);
                window.show_all ();
            }

            for (int i = 0; i < files.length; i++) {
                if (files[i].get_basename () == "--new-tab") {
                    window.on_new_clicked ();
                } else {
                    window.load_file (files[i].get_path ());
                }
            }

        }

        protected override void activate () {

            if (get_windows () == null) {
                window = new MainWindow ();
                window.set_application (this);
                window.show_all ();
            } else {
                window.present ();
            }

        }

        public override void show_about () {

            if (about_dlg != null) {
				about_dlg.get_window ().raise ();
				return;
			}
			
			about_dlg = new AboutDialog ();

            about_dlg.set_transient_for (window);
            about_dlg.set_modal (true);
			
			about_dlg.set_program_name (program_name);
			about_dlg.set_version (build_version + "\n" + build_version_info);
			about_dlg.set_logo_icon_name (app_icon);
			
			about_dlg.set_comments (program_name + ". " + build_release_name);
			about_dlg.set_copyright ("Copyright © %s %s Developers".printf (app_copyright, program_name));
			about_dlg.set_website (main_url);
			about_dlg.set_website_label ("Website");
			
			about_dlg.set_authors (about_authors);
			about_dlg.set_documenters (about_documenters);
			about_dlg.set_artists (about_artists);
			about_dlg.set_translator_credits (about_translators);
			
			about_dlg.response.connect (() => {
				about_dlg.hide ();
			});
			about_dlg.hide.connect (() => {
				about_dlg.destroy ();
				about_dlg = null;
			});
			
			about_dlg.show_all ();

        }

		public static int main (string[] args) {
            
            var app = new Scratch ();

		    return app.run (args);
		    
        }

    }
}
