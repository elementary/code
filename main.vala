/* 
compile with

 valac --pkg gtk+-2.0 main.vala main_window.vala toolbars.vala entry.vala toolbutton_with_menu.vala menu.vala -o editor
 
and launch with

 ./editor
*/

void main(string[] args)
{	
	
	if (args[1] != null) {
		Gtk.init (ref args);
		var window =new MainWindow (args[1]);
		window.show_all ();
		Gtk.main ();
	}
	
	else {
		Gtk.init (ref args);
		var window =new MainWindow ("");
		window.show_all ();
		Gtk.main ();
	}
}
