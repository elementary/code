
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
		store = new Granite.Widgets.SourceList ();
		store.get_style_context ().add_class ("sidebar");
		store.item_selected.connect ((selected) => {
			if (selected == null) return;
			goto (doc, (selected as CtagsSymbol).line);
			store.selected = null;
		});
		root = new Granite.Widgets.SourceList.ExpandableItem (_("Symbols"));
		store.root.add (root);
	}

	public void parse_symbols ()
	{
		var command = new Granite.Services.SimpleCommand (Environment.get_home_dir (), "/usr/bin/ctags -f - --format=2 --excmd=pattern "+
		   "--fields=ns --extra= --sort=no " + doc.file.get_path ());
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
			// 2 => excerpt from file
			var line = int.parse (parts[3].substring (5)); // line:n
			var parent = parts.length > 4 ? parts[4].substring (6) : null; // class:name

			Granite.Widgets.SourceList.ExpandableItem? parent_symbol = null;
			if (parent != null) {
				parent_symbol = find_existing (name, line, root);
			}
			if (parent_symbol == null)
				parent_symbol = root;

			print ("ADDING %s\n", name);
			parent_symbol.add (new CtagsSymbol (doc, name, line));
		}

		store.root.expand_all ();
	}

	CtagsSymbol? find_existing (string name, int line, Granite.Widgets.SourceList.ExpandableItem parent)
	{
		CtagsSymbol match = null;
		foreach (var child in parent.children) {
			var child_symbol = child as CtagsSymbol;
			if (child_symbol.name == name && child_symbol.line == line) {
				match = child_symbol;
				break;
			} else {
				var res = find_existing (name, line, child_symbol);
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

