using Gtk;

public class MenuProperties : Menu {

	private MenuItem preferences;
	
	public MenuProperties () {
		draw ();
		this.show_all ();
	}
	
	public void draw () {		
		this.preferences = new MenuItem.with_label ("Hello");
		
		this.append (this.preferences);
	}
	
	public void connect_signals () {
		this.destroy.connect (Gtk.main_quit);
			
	}
	
	
}
