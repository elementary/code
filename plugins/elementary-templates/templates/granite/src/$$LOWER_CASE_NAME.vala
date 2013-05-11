

namespace $$NAME {
    
    public class $$NAMEApp : Granite.Application {
        
        construct {
            program_name = "$$NAME";
            exec_name = "$$NAME";
            
            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;
            
            app_years = "2012";
            app_icon = "$$LOWER_CASE_NAME";
            app_launcher = "$$LOWER_CASE_NAME.desktop";
            application_id = "net.launchpad.$$LOWER_CASE_NAME";
            
            main_url = "https://code.launchpad.net/$$LOWER_CASE_NAME";
            bug_url = "https://bugs.launchpad.net/$$LOWER_CASE_NAME";
            help_url = "https://code.launchpad.net/$$LOWER_CASE_NAME";
            translate_url = "https://translations.launchpad.net/$$LOWER_CASE_NAME";
            
            about_authors = {"$$AUTHORS"};
            about_documenters = {"$$AUTHORS"};
            about_artists = {"$$AUTHORS"};
            about_comments = "$$DESCRIPTION";
            about_translators = "";
            about_license_type = Gtk.License.GPL_3_0;
        }
        
        public $$NAMEApp () {
            
        }
        
        //the application started
        public override void activate () {
            
        }
        
        //the application was requested to open some files
        public override void open (File [] files, string hint) {
            
        }
    }
}

public static void main (string [] args) {
    Gtk.init (ref args);
    
    var app = new $$NAME.$$NAMEApp ();
    
    app.run (args);
}

