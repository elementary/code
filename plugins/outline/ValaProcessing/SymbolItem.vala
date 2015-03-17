

public class SymbolItem : Granite.Widgets.SourceList.ExpandableItem, Granite.Widgets.SourceListSortable {
    public Vala.Symbol symbol { get; set; }

    public SymbolItem (Vala.Symbol symbol) {
        this.symbol = symbol;
        this.name = symbol.name;
        if (symbol is Vala.CreationMethod) {
            if (symbol.name == ".new")
                this.name = ((Vala.CreationMethod)symbol).class_name;
            else
                this.name = "%s.%s".printf (((Vala.CreationMethod)symbol).class_name, symbol.name);
        }
    }

    public int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
        return Comparison.sort_function (a, b);
    }

    public bool allow_dnd_sorting () {
        return false;
    }

    public bool compare_symbol (Vala.Symbol comp_symbol) {
        if (comp_symbol.name != symbol.name)
            return false;

        Vala.Symbol comp_parent = comp_symbol.parent_symbol;
        for (var parent = symbol.parent_symbol; parent != null; parent = parent.parent_symbol) {
            comp_parent = comp_parent.parent_symbol;
            if (comp_parent == null)
                return false;

            if (comp_parent.name != parent.name)
                return false;
        }

        if (comp_parent.parent_symbol != null)
            return false;

        return true;
    }
}
