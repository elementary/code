/*-
 * Copyright (c) 2017-2018 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

public class Code.Plugins.Outline.ValaSymbolResolver : Vala.SymbolResolver {
    private Gee.TreeSet<Vala.Property> properties = new Gee.TreeSet<Vala.Property> ();
    private Gee.TreeSet<Vala.Symbol> symbols = new Gee.TreeSet<Vala.Symbol> ();

    public Gee.TreeSet<Vala.Field> get_properties_fields () {
        var return_fields = new Gee.TreeSet<Vala.Field> ();
        foreach (var prop in properties) {
            if (prop.field != null) {
                return_fields.add (prop.field);
            }
        }

        return return_fields;
    }

    public Gee.TreeSet<Vala.Symbol> get_symbols () {
        var return_symbols = new Gee.TreeSet<Vala.Symbol> ();
        return_symbols.add_all (symbols);
        return return_symbols;
    }

    public void clear () {
        properties.clear ();
        symbols.clear ();
    }

    public override void visit_class (Vala.Class s) {
        symbols.add (s);
        base.visit_class (s);
    }

    public override void visit_constant (Vala.Constant s) {
        symbols.add (s);
        base.visit_constant (s);
    }

    public override void visit_delegate (Vala.Delegate s) {
        symbols.add (s);
        base.visit_delegate (s);
    }

    //FIXME both constructor and destructor are currently not added for some reason
    public override void visit_constructor (Vala.Constructor s) {
        symbols.add (s);
        base.visit_constructor (s);
    }

    public override void visit_destructor (Vala.Destructor s) {
        symbols.add (s);
        base.visit_destructor (s);
    }

    public override void visit_creation_method (Vala.CreationMethod s) {
        symbols.add (s);
        base.visit_creation_method (s);
    }

    public override void visit_enum (Vala.Enum s) {
        symbols.add (s);
        base.visit_enum (s);
    }

    public override void visit_field (Vala.Field s) {
        symbols.add (s);
        base.visit_field (s);
    }

    public override void visit_interface (Vala.Interface s) {
        symbols.add (s);
        base.visit_interface (s);
    }

    public override void visit_method (Vala.Method s) {
        symbols.add (s);
        base.visit_method (s);
    }

    public override void visit_namespace (Vala.Namespace s) {
        symbols.add (s);
        base.visit_namespace (s);
    }

    public override void visit_property (Vala.Property s) {
        symbols.add (s);
        properties.add (s);
        base.visit_property (s);
    }

    public override void visit_signal (Vala.Signal s) {
        symbols.add (s);
        base.visit_signal (s);
    }

    public override void visit_struct (Vala.Struct s) {
        symbols.add (s);
        base.visit_struct (s);
    }
}
