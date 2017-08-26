/*-
 * Copyright (c) 2015-2016 Adam Bieńkowski
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public class ValaSymbolTreeVisitor : Vala.SymbolResolver {
    private Gee.TreeSet<Vala.Symbol> symbols;

    public ValaSymbolTreeVisitor () {
        symbols = new Gee.TreeSet<Vala.Symbol> ();
    }

    public void clear () {
        symbols.clear ();
    }

    public Gee.TreeSet<Vala.Symbol> get_symbols (Vala.SourceFile source_file) {
        source_file.accept_children (this);

        var copy = new Gee.TreeSet<Vala.Symbol> ();
        copy.add_all (symbols);
        return copy;
    }

    public override void visit_class (Vala.Class symbol) {
        symbols.add (symbol);
        base.visit_class (symbol);
    }

    public override void visit_constant (Vala.Constant symbol) {
        symbols.add (symbol);
        base.visit_constant (symbol);
    }

    public override void visit_delegate (Vala.Delegate symbol) {
        symbols.add (symbol);
        base.visit_delegate (symbol);
    }

    public override void visit_constructor (Vala.Constructor symbol) {
        symbols.add (symbol);

        // TODO: for some reason this throws a lot of warnings
        base.visit_constructor (symbol);
    }

    public override void visit_destructor (Vala.Destructor symbol) {
        symbols.add (symbol);

        // TODO: for some reason this throws a lot of warnings
        base.visit_destructor (symbol);
    }

    public override void visit_creation_method (Vala.CreationMethod symbol) {
        symbols.add (symbol);
        base.visit_creation_method (symbol);
    }

    public override void visit_enum (Vala.Enum symbol) {
        symbols.add (symbol);
        base.visit_enum (symbol);
    }

    public override void visit_field (Vala.Field symbol) {
        symbols.add (symbol);
        base.visit_field (symbol);
    }

    public override void visit_interface (Vala.Interface symbol) {
        symbols.add (symbol);
        base.visit_interface (symbol);
    }

    public override void visit_method (Vala.Method symbol) {
        symbols.add (symbol);

        // TODO: for some reason this throws a lot of warnings
        base.visit_method (symbol);
    }

    public override void visit_namespace (Vala.Namespace symbol) {
        symbols.add (symbol);
        base.visit_namespace (symbol);
    }

    public override void visit_property (Vala.Property symbol) {
        symbols.add (symbol);
        base.visit_property (symbol);
    }

    public override void visit_signal (Vala.Signal symbol) {
        symbols.add (symbol);
        base.visit_signal (symbol);
    }

    public override void visit_struct (Vala.Struct symbol) {
        symbols.add (symbol);
        base.visit_struct (symbol);
    }    
}
