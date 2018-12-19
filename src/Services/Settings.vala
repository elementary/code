// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2013 Mario Guerriero <mario@elementaryos.org>
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


namespace Scratch {

    public enum ScratchWindowState {
        NORMAL = 0,
        MAXIMIZED = 1,
        FULLSCREEN = 2
    }

    public enum ScratchDrawSpacesState {
        NEVER = 0,
        FOR_SELECTION = 1,
        ALWAYS = 2
    }

    public class SavedState : Granite.Services.Settings {

        public int window_width { get; set; }
        public int window_height { get; set; }
        public ScratchWindowState window_state { get; set; }
        public int window_x { get; set; }
        public int window_y { get; set; }

        public int hp1_size { get; set; }
        public int vp_size { get; set; }

        public SavedState () {
            base (Constants.PROJECT_NAME + ".saved-state");
        }

    }

    public class Settings : Granite.Services.Settings {

        public bool highlight_matching_brackets { get; set; }
        public ScratchDrawSpacesState draw_spaces { get; set; }
        public bool spaces_instead_of_tabs { get; set; }
        public bool line_wrap { get; set; }
        public bool auto_indent { get; set; }
        public int indent_width { get; set; }
        public bool show_right_margin { get; set; }
        public int right_margin_position { get; set; }
        public bool use_system_font { get; set; }
        public string font { get; set; }
        public string style_scheme { get; set; }
        public string[] plugins_enabled { get; set;}
        public string[] opened_files_view1 { get; set; }
        public string[] opened_files_view2 { get; set; }
        public bool autosave { get; set; }
        public bool smart_cut_copy { get; set; }
        public string focused_document_view1 { get; set; }
        public string focused_document_view2 { get; set; }
        public bool show_mini_map { get; set; }
        public bool prefer_dark_style { get; set; }

        public Settings ()  {
            base (Constants.PROJECT_NAME + ".settings");
        }

    }

    public class ServicesSettings : Granite.Services.Settings {

        public string paste_format_code { get; set; }
        public string expiry_time { get; set; }
        public bool set_private { get; set; }

        public ServicesSettings () {
            base (Constants.PROJECT_NAME + ".services");
        }

    }

    public class FolderManagerSettings : Granite.Services.Settings {

        private const string SCHEMA = Constants.PROJECT_NAME + ".folder-manager";

        public string[] opened_folders { get; set; }

        public FolderManagerSettings () {
            base (SCHEMA);
        }
    }

}
