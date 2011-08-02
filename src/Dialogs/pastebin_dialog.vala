/***
  BEGIN LICENSE
	
  Copyright (C) 2011 Giulio Collura <random.cpp@gmail.com>
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

using Gtk;

using Scratch.Services;

namespace Scratch.Dialogs {

    public class PasteBinDialog : Window {
        
        private MainWindow window;

        private VBox content;
        private HBox padding;

        private Entry name_entry;
        private Entry format_entry;
        private ComboBoxText expiry_combo;
        private CheckButton private_check;

        private Button cancel_button;
        private Button send_button;

        public PasteBinDialog (MainWindow? window) {

            this.window = window;
            this.title = "Share via PasteBin";
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            this.set_modal (true);
            this.set_transient_for (window);
            
            create_dialog ();

            send_button.clicked.connect (send_button_clicked);
            cancel_button.clicked.connect (cancel_button_clicked);

        }

        private void create_dialog () {

            content = new VBox (false, 10);
            padding = new HBox (false, 10);

            name_entry = new Entry ();
            name_entry.text = "Test";
            var name_entry_l = new Label ("Name:");
            var name_entry_box = new HBox (false, 58);
            name_entry_box.pack_start (name_entry_l, false, true, 0);
            name_entry_box.pack_start (name_entry, true, true, 0);

            format_entry = new Entry ();
            format_entry.text = "None";
            var format_entry_l = new Label ("Code highlight:");
            var format_entry_box = new HBox (false, 10);
            format_entry_box.pack_start (format_entry_l, false, true, 0);
            format_entry_box.pack_start (format_entry, true, true, 0);

            expiry_combo = new ComboBoxText ();
            populate_expiry_combo ();
            var expiry_combo_l = new Label ("Expiry time:");
            var expiry_combo_box = new HBox (false, 28);
            expiry_combo_box.pack_start (expiry_combo_l, false, true, 0);
            expiry_combo_box.pack_start (expiry_combo, true, true, 0);

            private_check = new CheckButton.with_label ("Keep this paste private");

            cancel_button = new Button.from_stock (Stock.CANCEL);
            send_button = new Button.with_label ("Upload");

            var bottom_buttons = new HButtonBox ();
            bottom_buttons.set_layout (ButtonBoxStyle.CENTER);
            bottom_buttons.set_spacing (10);
            bottom_buttons.pack_start (cancel_button);
            bottom_buttons.pack_end (send_button);

            content.pack_start (wrap_alignment (name_entry_box, 12, 0, 0, 0), true, true, 0);
            content.pack_start (format_entry_box, true, true, 0);
            content.pack_start (expiry_combo_box, true, true, 0);
            content.pack_start (private_check, true, true, 0);
            content.pack_end (bottom_buttons, true, true, 12);

            padding.pack_start (content, false, true, 12);

            add (padding);

            read_settings ();

            show_all ();
            send_button.grab_focus ();

        }

        private static Alignment wrap_alignment (Widget widget, int top, int right,
                                                 int bottom, int left) {

            var alignment = new Alignment (0.0f, 0.0f, 1.0f, 1.0f);
            alignment.top_padding = top;
            alignment.right_padding = right;
            alignment.bottom_padding = bottom;
            alignment.left_padding = left;
            
            alignment.add(widget);
            return alignment;

        }

        private void read_settings () {

            string paste_name = window.current_tab.label.label.label;
            name_entry.text = paste_name;

            format_entry.text = Scratch.services.paste_format_code;
            expiry_combo.set_active_id (Scratch.services.expiry_time);
            private_check.set_active (Scratch.services.set_private);

        }

        private void write_settings () {

            Scratch.services.paste_format_code = format_entry.text;
            Scratch.services.expiry_time = expiry_combo.get_active_id ();
            Scratch.services.set_private = private_check.get_active ();

        }

        private void cancel_button_clicked () {
            
            write_settings ();
            this.destroy ();

        }

        private void close_button_clicked () {
            
            write_settings ();
            this.destroy ();

        }

        private void send_button_clicked () {

            content.hide ();

            // Probably your connection is too fast to not see this
            var spinner = new Spinner ();
            padding.pack_start (spinner, true, true, 10);
            spinner.show ();
            spinner.start ();

            string link = submit_paste ();

            // Show the new view
            spinner.hide ();
            var link_button = new LinkButton (link);
            var close_button = new Button.from_stock (Stock.CLOSE);
            var box = new VBox (false, 10);
            box.pack_start (link_button, false, true, 0);
            box.pack_start (close_button, false, true, 0);
            padding.pack_start (box, false, true, 12);
            padding.halign = Align.CENTER;
            box.valign = Align.CENTER;
            box.show_all ();
            // Copy link to clipboard
            set_clipboard (link);
            // Connect signal
            close_button.clicked.connect (close_button_clicked);

        }

        private string submit_paste () {

            // Get the values
            string paste_code = window.current_tab.text_view.buffer.text;
            string paste_name = name_entry.text;
            string paste_format = format_entry.text;
            string paste_private = private_check.get_active () == true ? PasteBin.PRIVATE : PasteBin.PUBLIC;
            string paste_expire_date = expiry_combo.get_active_id ();

            string link = PasteBin.submit (paste_code, paste_name, paste_private,
                                           paste_expire_date, paste_format);

            return link;

        }
        
        private void set_clipboard (string link) {

            var display = window.get_display ();
            var clipboard = Clipboard.get_for_display (display, Gdk.SELECTION_CLIPBOARD);
            clipboard.set_text (link, -1);

        }

        private void populate_expiry_combo () {

            expiry_combo.append (PasteBin.NEVER, "Never");
            expiry_combo.append (PasteBin.TEN_MINUTES, "Ten minutes");
            expiry_combo.append (PasteBin.HOUR, "One hour");
            expiry_combo.append (PasteBin.DAY, "One day");
            expiry_combo.append (PasteBin.MONTH, "One month");

        }

    }

}
