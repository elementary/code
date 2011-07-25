/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Mario Guerriero <mefrio.g@gmail.com>	
  This program is free software: you can redistribute it and/or modify it	
  under the terms of the GNU Lesser General Public License version 3, as published	
  by the Free Software Foundation.
	
  This program is distributed in the hope that it will be useful, but	
  WITHOUT ANY WARRANTY; without even the implied warranties of	
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR	
  PURPOSE.  See the GNU General Public License for more details.
	
  You should have received a copy of the GNU General Public License along	
  with this program.  If not, see <http://www.gnu.org/licenses/>	
  
  END LICENSE	
***/

public class ElementaryEntry : Gtk.Entry {

    public string hint_string;

    public ElementaryEntry (string hint_string) {
    
        this.hint_string = hint_string;
        
        this.hint ();
        this.focus_in_event.connect (on_focus_in);
        this.focus_out_event.connect (on_focus_out);
    
    }

    private bool on_focus_in () {
    
        if (get_text () == "") {
            unhint ();
        }
        return false;
    
    }
    
    private bool on_focus_out () {
    
        if (get_text () == "") {
            hint ();
        }
        return false;
    
    }
    
    protected void hint () {

        this.text = this.hint_string;
        grey_out ();
    
    }

    protected void unhint () {
    
        this.text = "";
        reset_font ();
    
    }
    
    
    private void grey_out () {
    
        var color = Gdk.Color ();
        Gdk.Color.parse ("#999", out color);
        this.modify_text (Gtk.StateType.NORMAL, color);
        this.modify_font (Pango.FontDescription.from_string ("italic"));
    
    }
    
    private void reset_font () {
    
        var color = Gdk.Color ();
        Gdk.Color.parse ("#444", out color);
        this.modify_text (Gtk.StateType.NORMAL, color);
        this.modify_font (Pango.FontDescription.from_string ("normal"));
    
    }
    
    protected new string get_text () {
    
        text = this.text;
        if (text == this.hint_string) {
            return "";
        }
        else {
            return text;
        }
    
    }
}

public class ElementarySearchEntry : ElementaryEntry {

    bool is_searching;

    public ElementarySearchEntry (string hint_string) {
    
        base(hint_string);
        this.set_icon_from_stock(Gtk.EntryIconPosition.PRIMARY, "gtk-find");
        this.changed.connect (manage_icon);
        this.focus_in_event.connect (on_focus_in);
        this.focus_out_event.connect (on_focus_out);
        this.icon_press.connect (icon_pressed);
        setup_clear_icon ();
        this.is_searching = true;
        
    }

    private void setup_clear_icon () {
    
        var stock_item = Gtk.StockItem ();
        stock_item.stock_id = "edit-clear-symbolic";
        stock_item.label = null;
        stock_item.modifier = 0;
        stock_item.keyval = 0;
        stock_item.translation_domain = Gtk.Stock.CLEAR;
        var factory = new Gtk.IconFactory ();
        var icon_set = new Gtk.IconSet ();
        var icon_source = new Gtk.IconSource ();
        icon_source.set_icon_name (Gtk.Stock.CLEAR);
        icon_set.add_source (icon_source);
        icon_source.set_icon_name ("edit-clear-symbolic");
        icon_set.add_source (icon_source);
        factory.add ("edit-clear-symbolic", icon_set);
        Gtk.Stock.add ({stock_item});
        factory.add_default ();
        
    }

    private new void hint () {
    
        this.is_searching = false;
        this.set_icon_from_stock (Gtk.EntryIconPosition.SECONDARY, null);
        base.hint ();
        
    }
    
    private new bool on_focus_in () {
    
        if (!this.is_searching) {
            this.unhint ();
            this.is_searching = false;
        }
        return false;
    
    }

    private new bool on_focus_out () {
        
        if (this.get_text() == "") {
            this.hint ();
            this.is_searching = false;
        }
        return false;
    
    }

    private void manage_icon () {

        if (this.text != "") {
            this.set_icon_from_stock (Gtk.EntryIconPosition.SECONDARY, "edit-clear-symbolic");
        }
        else {
            this.set_icon_from_stock (Gtk.EntryIconPosition.SECONDARY, null);
        }
        
    }

    private void icon_pressed (Gtk.EntryIconPosition icon_position) {
    
        if (icon_position == Gtk.EntryIconPosition.SECONDARY) {
            this.is_searching = false;
            this.text = "";
            this.set_icon_from_stock(Gtk.EntryIconPosition.SECONDARY, null);
            this.is_searching = true;
        }
        else {
            if (!this.is_focus) {
                this.is_searching = false;
                this.hint ();
            }
        }
        
    }
}
