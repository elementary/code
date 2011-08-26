// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
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
                             "Gabriele Coletta <gdmg92@gmail.com>",
                             null
                             };
        	//about_documenters = {"",""};
		    about_artists = {"Harvey Cabaguio 'BassUltra' <harveycabaguio@gmail.com>",
                             null
                             };
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


		public static int main (string[] args) {
            
            var app = new Scratch ();

		    return app.run (args);
		    
        }

    }
}
