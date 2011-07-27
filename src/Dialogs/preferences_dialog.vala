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

namespace Scratch.Dialogs {

    public class Preferences : Window {

        private MainWindow window;

        private VBox content;
        private HBox padding;

        private Label editor_label;

        private CheckButton line_numbers;
        private CheckButton highlight_current_line;
        private CheckButton spaces_instead_of_tabs;
        private SpinButton indent_width;

        private Button close_button;

        public Preferences (string? title, MainWindow? window) {
            
            this.window = window;
            this.title = title;
            this.type_hint = Gdk.WindowTypeHint.DIALOG;
            this.set_modal (true);
            this.set_transient_for (window);
            
            set_default_size (400, 300);
            
            create_layout ();

            close_button.clicked.connect (close_button_clicked);

        }

        private void create_layout () {

            content = new VBox (false, 10);
            padding = new HBox (false, 10);

            editor_label = new Label ("Editor Settings");
            editor_label.xalign = 0.0f;
            editor_label.set_markup ("<b>Editor Settings</b>");
            
            line_numbers = new CheckButton.with_label ("Show line numbers");
            line_numbers.set_active (Scratch.settings.show_line_numbers);

            highlight_current_line = new CheckButton.with_label ("Highlight current line");
            highlight_current_line.set_active (Scratch.settings.highlight_current_line);

            spaces_instead_of_tabs = new CheckButton.with_label ("Use spaces instead of tabs");
            spaces_instead_of_tabs.set_active (Scratch.settings.spaces_instead_of_tabs);

            indent_width = new SpinButton.with_range (1, 24, 1);
            indent_width.set_value (Scratch.settings.indent_width);
            var indent_width_l = new Label ("Tab width: ");
            var indent_width_box = new HBox (false, 5);
            indent_width_box.pack_start (indent_width_l, false, true, 0);
            indent_width_box.pack_start (indent_width, false, true, 0);

            close_button = new Button.with_label ("Close");

            var bottom_buttons = new HButtonBox ();
            bottom_buttons.set_layout (ButtonBoxStyle.END);
            bottom_buttons.pack_end (close_button);

            content.pack_start (wrap_alignment (editor_label, 10, 0, 0, 0), false, true, 0);
            content.pack_start (wrap_alignment (line_numbers, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (highlight_current_line, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (spaces_instead_of_tabs, 0, 0, 0, 10), false, true, 0);
            content.pack_start (wrap_alignment (indent_width_box, 0, 0, 0, 10), false, true, 0);
            
            content.pack_end (bottom_buttons, false, true, 10);

            padding.pack_start (content, true, true, 10);

            add (padding);

            show_all ();

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

        private void close_button_clicked () {

            Scratch.settings.show_line_numbers = line_numbers.get_active ();
            Scratch.settings.highlight_current_line = highlight_current_line.get_active ();
            Scratch.settings.spaces_instead_of_tabs = spaces_instead_of_tabs.get_active ();
            Scratch.settings.indent_width = (int) indent_width.value;
            
            this.destroy ();

        }

    }

} // Namespace
