
public class CtagsSymbol : Granite.Widgets.SourceList.ExpandableItem
{
	public Scratch.Services.Document doc { get; construct set; }
	public int line { get; construct set; }

	public CtagsSymbol (Scratch.Services.Document doc, string name, int line)
	{
		Object (doc: doc, name: name, line: line);
	}
}

public class CtagsSymbolOutline : Object, SymbolOutline
{
	public Scratch.Services.Document doc { get; protected set; }
	Granite.Widgets.SourceList store;
	Granite.Widgets.SourceList.ExpandableItem root;

	public CtagsSymbolOutline (Scratch.Services.Document _doc)
	{
		doc = _doc;
		doc.doc_closed.connect (doc_closed);

		root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));

		store = new Granite.Widgets.SourceList ();
		store.get_style_context ().add_class ("sidebar");
		store.item_selected.connect ((selected) => {
			if (selected == null) return;
			goto (doc, (selected as CtagsSymbol).line);
			store.selected = null;
		});
		store.root.add (root);
	}

	~CtagsSymbolOutline ()
	{
		doc.doc_closed.disconnect (doc_closed);
	}

	void doc_closed (Scratch.Services.Document doc)
	{
		closed ();
	}

	public void parse_symbols ()
	{
		var command = new Granite.Services.SimpleCommand (Environment.get_home_dir (),
			"/usr/bin/ctags -f - --format=2 --excmd=n --fields=nsK --extra= "+
			"--sort=no " + doc.file.get_path ());
		command.done.connect (parse_output);
		command.run ();
	}

	void parse_output (Granite.Services.SimpleCommand command, int status)
	{
		root.clear ();

		if (status != 0)
			error ("Ctags failed\n");

		var symbols = command.standard_output_str.split ("\n");
		foreach (var symbol in symbols) {
			if (symbol == "")
				continue;

			var parts = symbol.split ("\t");
			var name = parts[0];
			// 1 => filename
			// 2 => line number with weird trailing chars
			var type = parts[3];
			int line = 0;
			string parent = null;
			parse_fields (string.joinv (" ", parts[4:parts.length - 1]), out line, out parent);

			Granite.Widgets.SourceList.ExpandableItem? parent_symbol = null;
			if (parent != null) {
				parent_symbol = find_existing (parent, root);
			}
			if (parent_symbol == null)
				parent_symbol = root;

			var s = new CtagsSymbol (doc, name, line);
			// let's guess we have a constructor here
			if (s.name == parent_symbol.name)
				type = "constructor";

			switch (type) {
				case "class":
				case "struct":
					s.icon = new ThemedIcon.from_names ({"user-home-symbolic", "go-home-symbolic", "user-home", "go-home", "home"});
					break;
				case "field":
				case "constant":
					s.icon = new ThemedIcon.with_default_fallbacks ("view-grid-symbolic");
					break;
				case "constructor":
					s.icon = new ThemedIcon.with_default_fallbacks ("media-playback-start-symbolic");
					break;
				case "desctructor":
					s.icon = new ThemedIcon.with_default_fallbacks ("edit-delete-symbolic");
					break;
				case "enum":
					s.icon = new ThemedIcon.with_default_fallbacks ("view-list-compact-symbolic");
					break;
				case "method":
					s.icon = new ThemedIcon.with_default_fallbacks ("document-properties-symbolic");
					break;
				case "namespace":
				case "package":
					s.icon = new ThemedIcon.with_default_fallbacks ("view-fullscreen-symbolic");
					break;
				case "property":
					s.icon = new ThemedIcon.with_default_fallbacks ("format-indent-more-symbolic");
					break;
			}
			parent_symbol.add (s);
		}

		store.root.expand_all ();
		store.show_all ();
		store.get_parent ().show_all ();
	}

	void parse_fields (string fields, out int line, out string parent)
	{
		var index = -1;
		if ((index = fields.index_of ("line:")) > -1)
			line = int.parse (fields.substring (index + 5, int.max (fields.index_of (" ", index + 6) - index, -1)));
		if ((index = fields.index_of ("class:")) > -1) {
			parent = fields.substring (index + 6, int.max (fields.index_of (" ", index + 7) - index, -1));
		}
	}

	CtagsSymbol? find_existing (string name, Granite.Widgets.SourceList.ExpandableItem parent)
	{
		CtagsSymbol match = null;
		foreach (var child in parent.children) {
			var child_symbol = child as CtagsSymbol;
			if (child_symbol.name == name) {
				match = child_symbol;
				break;
			} else {
				var res = find_existing (name, child_symbol);
				if (res != null)
					return res;
			}
		}
		return match;
	}

	public static string[] get_supported_types ()
	{
		string stdout;
		Process.spawn_sync (null, {"/usr/bin/ctags", "--list-languages"}, null, 0, null, out stdout);
		return stdout.split ("\n");
	}

	public Granite.Widgets.SourceList get_source_list ()
	{
		return store;
	}
}

