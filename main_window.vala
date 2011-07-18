using Gtk;

public class MainWindow : Window {

	private const string TITLE = "Scratch";
	
	private TextView text_view;
	
	public MainWindow (string arg) {
		if (arg == "") {
			this.title = this.TITLE;
		}
		else {
			this.title = arg;
		}
		
		load_file (arg);
		
		this.set_default_size (800, 500);
		this.maximize ();
		
		draw_window();
		connect_signals();
	}
	
	public void draw_window () {
		//drawing the hbox		
		var toolbar = new EditorToolbar ();
		
		//textview and its scrolledwindow
		var scrolled = new ScrolledWindow (null, null);
		scrolled.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		this.text_view = new TextView ();
		scrolled.add (text_view);
		//addingo all to the vbox
		var vbox = new VBox (false, 0);
		vbox.pack_start (toolbar, false, false, 0);
		vbox.pack_start (scrolled, true, true, 0); 
		
		this.add (vbox);		
	
	}
	
	public void connect_signals () {
		this.destroy.connect (Gtk.main_quit);
			
	}
	
	public void load_file (string filename) {
		if (filename != "") {
			try {
				string text;
           			FileUtils.get_contents (filename, out text);
          			this.text_view.buffer.text = text;
			} catch (Error e) {
         	   		stderr.printf ("Error: %s\n", e.message);
        		}
		}
			
	}
	
}
	
