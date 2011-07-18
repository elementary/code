using Gtk;

public class ToolbarBasic : Toolbar {

	public ToolButton new_;
	public ToolButton open_;
	public ToolButton save_;
	public SeparatorToolItem separator1;
	public ToolButton cancel_;
	public ToolButton repeat_;
	public ToolItem combo;
	public ComboBox cb;
	public SeparatorToolItem separator2;

	public ToolbarBasic () {
		draw ();
		connect_signals ();	
	}
	
	public void draw () {
		this.new_ = new ToolButton.from_stock(Stock.NEW);
		this.open_ = new ToolButton.from_stock (Stock.OPEN);
		this.save_ = new ToolButton.from_stock (Stock.SAVE);
		this.separator1 = new SeparatorToolItem ();
		this.cancel_ = new ToolButton.from_stock (Stock.UNDO);
		this.repeat_ = new ToolButton.from_stock (Stock.REDO);
		this.separator2 = new SeparatorToolItem ();
		this.combo = new ToolItem ();
		
		this.cb = new ComboBox ();
		this.combo.add (cb);
		this.combo.set_expand (false);		
		
		this.add (new_);
		this.add (open_);
		this.add (save_);
		this.add (separator1);
		this.add (cancel_);
		this.add (repeat_);
		this.add (separator2);
		this.add (combo);
	}
	
	public void connect_signals () {
		this.new_.clicked.connect (create_new) ;				
	}
	
	public void create_new () {
		var window =new MainWindow ("");
		window.show_all ();
		Gtk.main ();
	}

}

public class ToolbarSearch : Toolbar {

	public SeparatorToolItem separator;
	public ToolItem entry_cont;
	public Entry entry;
	public ToolButtonWithMenu properties_;

	public ToolbarSearch () {
		draw ();	
	}
	
	public void draw () {
		
		this.separator = new SeparatorToolItem ();	
		
		this.entry = new ElementarySearchEntry ("Search in the text...");
		this.entry_cont = new ToolItem ();
		this.entry_cont.add (entry);	
		this.entry_cont.set_expand (true);	
			
		var image = new Image.from_stock (Stock.PROPERTIES, IconSize.LARGE_TOOLBAR);
		var menu = new MenuProperties (); 
			
		this.properties_ = new ToolButtonWithMenu (image, "Properties", menu);
		
		this.add (separator);
		this.add (entry_cont);		
		this.add (properties_);
				
	}
	
	public int connect_signals () {
		return 0;	
	}
	
}

public class EditorToolbar : HBox {

	public EditorToolbar () {
		draw ();	
	}
	
	public void draw () {
		
		var toolbar = new ToolbarBasic ();
		
		var toolbar1 = new ToolbarSearch ();
		
		this.pack_start (toolbar, true, true, 0);
		this.pack_end (toolbar1, true, true, 0);

	}

}
