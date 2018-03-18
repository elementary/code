// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Giulio Collura <random.cpp@gmail.com>
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

using Scratch.Services;

namespace Scratch.Dialogs {

    public class PasteBinDialog : Gtk.Dialog {

        public string[,] languages = {
            //if default, code, desc, scratch-equivalent
            {"n", "4cs", "4CS", ""},
            {"n", "6502acme", "6502 ACME Cross Assembler", ""},
            {"n", "6502kickass", "6502 Kick Assembler", ""},
            {"n", "6502tasm", "6502 TASM/64TASS", ""},
            {"n", "abap", "ABAP", ""},
            {"n", "actionscript", "ActionScript", ""},
            {"n", "actionscript3", "ActionScript 3", ""},
            {"n", "ada", "Ada", ""},
            {"n", "algol68", "ALGOL 68", ""},
            {"n", "apache", "Apache Log", ""},
            {"n", "applescript", "AppleScript", ""},
            {"n", "apt_sources", "APT Sources", ""},
            {"n", "asm", "ASM (NASM)", ""},
            {"n", "asp", "ASP", ""},
            {"n", "autoconf", "autoconf", ""},
            {"n", "autohotkey", "Autohotkey", ""},
            {"n", "autoit", "AutoIt", ""},
            {"n", "avisynth", "Avisynth", ""},
            {"n", "awk", "Awk", ""},
            {"n", "bascomavr", "BASCOM AVR", ""},
            {"n", "bash", "Bash", "sh"},
            {"n", "basic4gl", "Basic4GL", ""},
            {"n", "bibtex", "BibTeX", ""},
            {"n", "blitzbasic", "Blitz Basic", ""},
            {"n", "bnf", "BNF", ""},
            {"n", "boo", "BOO", ""},
            {"n", "bf", "BrainFuck", ""},
            {"n", "c", "C", "c"},
            {"n", "c_mac", "C for Macs", ""},
            {"n", "cil", "C Intermediate Language", ""},
            {"n", "csharp", "C#", "c-sharp"},
            {"n", "cpp", "C++", "cpp"},
            {"n", "cpp-qt", "C++ (with QT extensions)", ""},
            {"n", "c_loadrunner", "C: Loadrunner", ""},
            {"n", "caddcl", "CAD DCL", ""},
            {"n", "cadlisp", "CAD Lisp", ""},
            {"n", "cfdg", "CFDG", ""},
            {"n", "chaiscript", "ChaiScript", ""},
            {"n", "clojure", "Clojure", ""},
            {"n", "klonec", "Clone C", ""},
            {"n", "klonecpp", "Clone C++", ""},
            {"n", "cmake", "CMake", "cmake"},
            {"n", "cobol", "COBOL", ""},
            {"n", "coffeescript", "CoffeeScript", ""},
            {"n", "cfm", "ColdFusion", ""},
            {"n", "css", "CSS", "css"},
            {"n", "cuesheet", "Cuesheet", ""},
            {"n", "d", "D", ""},
            {"n", "dcs", "DCS", ""},
            {"n", "delphi", "Delphi", ""},
            {"n", "oxygene", "Delphi Prism (Oxygene)", ""},
            {"n", "diff", "Diff", "diff"},
            {"n", "div", "DIV", ""},
            {"n", "dos", "DOS", ""},
            {"n", "dot", "DOT", ""},
            {"n", "e", "E", ""},
            {"n", "ecmascript", "ECMAScript", ""},
            {"n", "eiffel", "Eiffel", ""},
            {"n", "email", "Email", ""},
            {"n", "epc", "EPC", ""},
            {"n", "erlang", "Erlang", ""},
            {"n", "fsharp", "F#", ""},
            {"n", "falcon", "Falcon", ""},
            {"n", "fo", "FO Language", ""},
            {"n", "f1", "Formula One", ""},
            {"n", "fortran", "Fortran", "fortran"},
            {"n", "freebasic", "FreeBasic", ""},
            {"n", "gambas", "GAMBAS", ""},
            {"n", "gml", "Game Maker", ""},
            {"n", "gdb", "GDB", ""},
            {"n", "genero", "Genero", ""},
            {"n", "genie", "Genie", ""},
            {"n", "gettext", "GetText", "gettext-translation"},
            {"n", "go", "Go", ""},
            {"n", "groovy", "Groovy", ""},
            {"n", "gwbasic", "GwBasic", ""},
            {"n", "haskell", "Haskell", ""},
            {"n", "hicest", "HicEst", ""},
            {"n", "hq9plus", "HQ9 Plus", ""},
            {"n", "html4strict", "HTML", "html"},
            {"n", "html5", "HTML 5", ""},
            {"n", "icon", "Icon", ""},
            {"n", "idl", "IDL", ""},
            {"n", "ini", "INI file", "ini"},
            {"n", "inno", "Inno Script", ""},
            {"n", "intercal", "INTERCAL", ""},
            {"n", "io", "IO", ""},
            {"n", "j", "J", ""},
            {"n", "java", "Java", "java"},
            {"n", "java5", "Java 5", ""},
            {"n", "javascript", "JavaScript", "js"},
            {"n", "jquery", "jQuery", ""},
            {"n", "kixtart", "KiXtart", ""},
            {"n", "latex", "Latex", "latex"},
            {"n", "lb", "Liberty BASIC", ""},
            {"n", "lsl2", "Linden Scripting", ""},
            {"n", "lisp", "Lisp", ""},
            {"n", "llvm", "LLVM", ""},
            {"n", "locobasic", "Loco Basic", ""},
            {"n", "logtalk", "Logtalk", ""},
            {"n", "lolcode", "LOL Code", ""},
            {"n", "lotusformulas", "Lotus Formulas", ""},
            {"n", "lotusscript", "Lotus Script", ""},
            {"n", "lscript", "LScript", ""},
            {"n", "lua", "Lua", "lua"},
            {"n", "m68k", "M68000 Assembler", ""},
            {"n", "magiksf", "MagikSF", ""},
            {"n", "make", "Make", "makefile"},
            {"n", "mapbasic", "MapBasic", ""},
            {"n", "matlab", "MatLab", ""},
            {"n", "mirc", "mIRC", ""},
            {"n", "mmix", "MIX Assembler", ""},
            {"n", "modula2", "Modula 2", ""},
            {"n", "modula3", "Modula 3", ""},
            {"n", "68000devpac", "Motorola 68000 HiSoft Dev", ""},
            {"n", "mpasm", "MPASM", ""},
            {"n", "mxml", "MXML", ""},
            {"n", "mysql", "MySQL", ""},
            {"n", "newlisp", "newLISP", ""},
            {"n", "nsis", "NullSoft Installer", ""},
            {"n", "oberon2", "Oberon 2", ""},
            {"n", "objeck", "Objeck Programming Langua", ""},
            {"n", "objc", "Objective C", "objc"},
            {"n", "ocaml-brief", "OCalm Brief", ""},
            {"n", "ocaml", "OCaml", ""},
            {"n", "pf", "OpenBSD PACKET FILTER", ""},
            {"n", "glsl", "OpenGL Shading", ""},
            {"n", "oobas", "Openoffice BASIC", ""},
            {"n", "oracle11", "Oracle 11", ""},
            {"n", "oracle8", "Oracle 8", ""},
            {"n", "oz", "Oz", ""},
            {"n", "pascal", "Pascal", "pascal"},
            {"n", "pawn", "PAWN", ""},
            {"n", "pcre", "PCRE", ""},
            {"n", "per", "Per", ""},
            {"n", "perl", "Perl", "perl"},
            {"n", "perl6", "Perl 6", ""},
            {"n", "php", "PHP", "php"},
            {"n", "php-brief", "PHP Brief", ""},
            {"n", "pic16", "Pic 16", ""},
            {"n", "pike", "Pike", ""},
            {"n", "pixelbender", "Pixel Bender", ""},
            {"n", "plsql", "PL/SQL", ""},
            {"n", "postgresql", "PostgreSQL", ""},
            {"n", "povray", "POV-Ray", ""},
            {"n", "powershell", "Power Shell", ""},
            {"n", "powerbuilder", "PowerBuilder", ""},
            {"n", "proftpd", "ProFTPd", ""},
            {"n", "progress", "Progress", ""},
            {"n", "prolog", "Prolog", ""},
            {"n", "properties", "Properties", ""},
            {"n", "providex", "ProvideX", ""},
            {"n", "purebasic", "PureBasic", ""},
            {"n", "pycon", "PyCon", ""},
            {"n", "python", "Python", "python"},
            {"n", "q", "q/kdb+", ""},
            {"n", "qbasic", "QBasic", ""},
            {"n", "rsplus", "R", ""},
            {"n", "rails", "Rails", ""},
            {"n", "rebol", "REBOL", ""},
            {"n", "reg", "REG", ""},
            {"n", "robots", "Robots", ""},
            {"n", "rpmspec", "RPM Spec", ""},
            {"n", "ruby", "Ruby", "ruby"},
            {"n", "gnuplot", "Ruby Gnuplot", ""},
            {"n", "sas", "SAS", ""},
            {"n", "scala", "Scala", ""},
            {"n", "scheme", "Scheme", ""},
            {"n", "scilab", "Scilab", ""},
            {"n", "sdlbasic", "SdlBasic", ""},
            {"n", "smalltalk", "Smalltalk", ""},
            {"n", "smarty", "Smarty", ""},
            {"n", "sql", "SQL", ""},
            {"n", "systemverilog", "SystemVerilog", ""},
            {"n", "tsql", "T-SQL", ""},
            {"n", "tcl", "TCL", ""},
            {"n", "teraterm", "Tera Term", ""},
            {"n", "text", "None", "text"},
            {"n", "thinbasic", "thinBasic", ""},
            {"n", "typoscript", "TypoScript", ""},
            {"n", "unicon", "Unicon", ""},
            {"n", "uscript", "UnrealScript", ""},
            {"n", "vala", "Vala", "vala"},
            {"n", "vbnet", "VB.NET", ""},
            {"n", "verilog", "VeriLog", ""},
            {"n", "vhdl", "VHDL", ""},
            {"n", "vim", "VIM", ""},
            {"n", "visualprolog", "Visual Pro Log", ""},
            {"n", "vb", "VisualBasic", ""},
            {"n", "visualfoxpro", "VisualFoxPro", ""},
            {"n", "whitespace", "WhiteSpace", ""},
            {"n", "whois", "WHOIS", ""},
            {"n", "winbatch", "Winbatch", ""},
            {"n", "xbasic", "XBasic", ""},
            {"n", "xml", "XML", "xml"},
            {"n", "xorg_conf", "Xorg Config", ""},
            {"n", "xpp", "XPP", ""},
            {"n", "yaml", "YAML", ""},
            {"n", "z80", "Z80 Assembler", ""},
            {"n", "zxbasic", "ZXBasic", ""}
        };

        public Scratch.Services.Document doc { get; construct; }

        private Gtk.Button send_button;
        private Gtk.Entry name_entry;
        private Gtk.ComboBoxText expiry_combo;
        private Gtk.CheckButton private_check;
        private Gtk.ComboBoxText format_combo;
        private Gtk.Window format_others_win;
        private Gtk.TreeView format_others_view;
        private Gtk.ListStore format_store;
        private Gtk.Stack stack;

        public PasteBinDialog (Gtk.Window? parent, Scratch.Services.Document doc) {
            Object (
                border_width: 5,
                deletable: false,
                doc: doc,
                transient_for: parent,
                title: _("Share via PasteBin")
            );
        }

        construct {
            name_entry = new Gtk.Entry ();

            var name_entry_l = new Gtk.Label (_("Name:"));
            name_entry_l.halign = Gtk.Align.END;

            var format_label = new Gtk.Label (_("Format:"));
            format_label.halign = Gtk.Align.END;

            format_combo = new Gtk.ComboBoxText ();

            var format_button = new Gtk.Button.with_label (_("Others..."));
            format_button.clicked.connect (format_button_clicked);

            //populate combo box
            var sel_lang = doc.get_language_id ();
            for (var i = 0; i < languages.length[0]; i++) {
                //insert all languages that are in the scratch combo, and also those that are marked with "y"
                if ((languages[i, 3] != "") || (languages[i, 0] == "y")) {
                    format_combo.append (languages[i, 1], languages[i, 2]);
                }

                //if the inserted language is selected in scratch combo, select it as default
                if (languages[i, 3] == sel_lang ) {
                    format_combo.set_active_id (languages[i, 1]);
                }
            }

            //if no language is selected, select text as default
            if (format_combo.get_active_id () == null) {
                format_combo.set_active_id ("text");
            }

            var expiry_combo_l = new Gtk.Label (_("Expiry time:"));
            expiry_combo_l.halign = Gtk.Align.END;

            expiry_combo = new Gtk.ComboBoxText ();
            populate_expiry_combo ();

            private_check = new Gtk.CheckButton.with_label (_("Keep this paste private"));
            private_check.margin_top = 12;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 6;
            grid.row_spacing = 12;
            grid.margin = 5;
            grid.margin_top = 0;
            grid.attach (name_entry_l, 0, 0, 1, 1);
            grid.attach (name_entry, 1, 0, 1, 1);
            grid.attach (format_label, 0, 1, 1, 1);
            grid.attach (format_combo, 1, 1, 1, 1);
            grid.attach (format_button, 2, 1, 1, 1);
            grid.attach (expiry_combo_l, 0, 2, 1, 1);
            grid.attach (expiry_combo, 1, 2, 1, 1);
            grid.attach (private_check, 1, 3, 2, 1);

            var spinner = new Gtk.Spinner ();
            spinner.active = true;
            spinner.height_request = 32;
            spinner.valign = Gtk.Align.CENTER;

            stack = new Gtk.Stack ();
            stack.add (grid);
            stack.add (spinner);

            var content_area = get_content_area () as Gtk.Box;
            content_area.add (stack);

            send_button = new Gtk.Button.with_label (_("Upload"));

            var cancel_button = new Gtk.Button.with_label (_("Close"));

            var action_area = get_action_area () as Gtk.Box;
            action_area.margin_top = 7;
            action_area.add (cancel_button);
            action_area.add (send_button);

            read_settings ();

            show_all ();

            send_button.clicked.connect (() => {
                stack.visible_child = spinner;
                send_button_clicked ();
            });

            cancel_button.clicked.connect (() => {
                destroy ();
            });

            this.destroy.connect (() => {
                write_settings ();
            });
        }


        private void format_button_clicked () {
            format_others_win = new Gtk.Window ();
            format_others_win.modal = true;
            format_others_win.title = _("Other formats");
            format_others_win.set_default_size (250, 300);

            format_others_view = new Gtk.TreeView ();
            format_others_view.set_headers_visible (false);

            format_store = new Gtk.ListStore (2, typeof (string), typeof (string));
            format_others_view.set_model (format_store);
            format_others_view.insert_column_with_attributes (-1, "Language", new Gtk.CellRendererText (), "text", 0);

            Gtk.TreeIter iter;
            for (var i=0; i < languages.length[0]; i++) {
                format_store.append (out iter);
                format_store.set (iter, 0, languages[i, 2], 1, languages[i, 1]);
            }

            var format_others_scroll = new Gtk.ScrolledWindow (null, null);
            format_others_scroll.add (format_others_view);

            var format_others_ok = new Gtk.Button.from_icon_name ("dialog-ok", Gtk.IconSize.BUTTON);
            format_others_ok.clicked.connect (format_others_ok_clicked);

            var format_others_cancel = new Gtk.Button.from_icon_name ("dialog-cancel", Gtk.IconSize.BUTTON);
            format_others_cancel.clicked.connect (format_others_cancel_clicked);

            var format_others_buttons = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            format_others_buttons.set_layout (Gtk.ButtonBoxStyle.CENTER);
            format_others_buttons.pack_start (format_others_cancel);
            format_others_buttons.pack_start (format_others_ok);

            var format_others_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            format_others_box.pack_start (format_others_scroll);
            format_others_box.pack_start (format_others_buttons);

            format_others_win.add (format_others_box);
            format_others_win.show_all ();
        }

        private void format_others_cancel_clicked () {
            format_others_win.destroy ();
        }

        private void format_others_ok_clicked () {

            var selection = format_others_view.get_selection ();
            Gtk.TreeIter iter;
            if (selection.get_selected (null, out iter) == true) {
                Value lang_name;
                Value lang_code;
                format_store.get_value (iter, 0, out lang_name);
                format_store.get_value (iter, 1, out lang_code);

                format_combo.append ((string) lang_code, (string) lang_name);
                format_combo.set_active_id ((string) lang_code);
            }

            format_others_win.destroy ();
        }

        private void read_settings () {
            string paste_name = this.doc.get_basename ();
            name_entry.text = paste_name;

            expiry_combo.set_active_id (Scratch.services.expiry_time);
            private_check.set_active (Scratch.services.set_private);
        }

        private void write_settings () {
            Scratch.services.paste_format_code = format_combo.get_active_id ();
            Scratch.services.expiry_time = expiry_combo.get_active_id ();
            Scratch.services.set_private = private_check.get_active ();
        }

        private void send_button_clicked () {
            send_button.sensitive = false;

            string link;
            var submit_result = submit_paste (out link);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            stack.add (box);

            if (submit_result) {
                //paste successfully
                var link_button = new Gtk.LinkButton (link);
                box.pack_start (link_button, false, true, 25);
            } else {
                var err_label = new Gtk.Label (link);
                box.pack_start (err_label, false, true, 0);
            }

            box.show_all ();
            stack.visible_child = box;
        }


        private bool submit_paste (out string link) {
            // Get the values
            string paste_code = this.doc.get_text ();
            string paste_name = name_entry.text;
            string paste_format = format_combo.get_active_id ();
            string paste_private = private_check.get_active () == true ? PasteBin.PRIVATE : PasteBin.PUBLIC;
            string paste_expire_date = expiry_combo.get_active_id ();

            return PasteBin.submit (out link, paste_code, paste_name, paste_private, paste_expire_date, paste_format);
        }

        private void populate_expiry_combo () {
            expiry_combo.append (PasteBin.NEVER, _("Never"));
            expiry_combo.append (PasteBin.TEN_MINUTES, _("Ten minutes"));
            expiry_combo.append (PasteBin.HOUR, _("One hour"));
            expiry_combo.append (PasteBin.DAY, _("One day"));
            expiry_combo.append (PasteBin.MONTH, _("One month"));
        }
     }
}
