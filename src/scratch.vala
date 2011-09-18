// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Giulio Collura <random.cpp@gmail.com> 
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
using Gdk;

using Granite;
using Granite.Services;

namespace Scratch {

    public Scratch.Plugins.Manager plugins;
        public SavedState saved_state;
        public Settings settings;
        public ServicesSettings services;
        

    public class ScratchApp : Granite.Application {
    	
        public MainWindow window = null;
        static string app_cmd_name;

        construct {
        
            build_data_dir = Constants.DATADIR;
			build_pkg_data_dir = Constants.PKGDATADIR;
			build_release_name = Constants.RELEASE_NAME;
			build_version = Constants.VERSION;
			build_version_info = Constants.VERSION_INFO;
			
            program_name = app_cmd_name;
		    exec_name = app_cmd_name.down();
		    app_copyright = "GPLv3";
		    app_icon = "text-editor";
		    app_launcher = "scratch.desktop";
            application_id = "net.launchpad." + app_cmd_name.down();
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
		    about_license = """This program is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License version 3,
as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranties of
MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses>""";
		
		}

        public ScratchApp () {
			
			Logger.initialize ("Scratch");
			Logger.DisplayLevel = LogLevel.DEBUG;
            
            set_flags (ApplicationFlags.HANDLES_OPEN);

            saved_state = new SavedState ();
            settings = new Settings ();
            services = new ServicesSettings ();

            plugins = new Scratch.Plugins.Manager(settings.schema, "plugins-enabled", Constants.PLUGINDIR,  exec_name);
            plugins.hook_example("Example text");
            plugins.hook_app(this);
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
                    //
                    window.toolbar.toolreplace.hide ();
					window.toolbar.toolgoto.hide ();
					window.notebook_context.hide ();
					window.notebook_sidebar.hide ();
                } else {
                    window.open (files[i].get_path ());
                    //
                    window.toolbar.toolreplace.hide ();
					window.toolbar.toolgoto.hide ();
					window.notebook_context.hide ();
					window.notebook_sidebar.hide ();
                }
            }

        }

        protected override void activate () {

            if (get_windows () == null) {
                window = new MainWindow ();
                window.set_application (this);
                window.show ();
            } else {
                window.present ();
            }

        }


    static const OptionEntry[] entries = {
        { "set", 's', 0, OptionArg.STRING, ref app_cmd_name, "Set of plugins", "" },
        { null }
    };
		public static int main (string[] args) {
            app_cmd_name = "Scratch";
            var context = new OptionContext("File");
            context.add_main_entries(entries, "scratch");
            context.add_group(Gtk.get_option_group(true));
            try {
                context.parse(ref args);
            }
            catch(Error e) {
                print(e.message + "\n");
            }
            
            Gtk.init(ref args);

            var app = new ScratchApp ();

		    return app.run (args);
		    
        }

    }
}
