/***
  BEGIN LICENSE

  Copyright (C) 2011-2013 Mario Guerriero <mario@elementaryos.org>
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

public class ContractMenuItem : Gtk.MenuItem {
    private Granite.Services.Contract contract;
    private File file;

    public ContractMenuItem (Granite.Services.Contract contract, File file) {
        this.contract = contract;
        this.file = file;

        label = contract.get_display_name ();
        tooltip_text = contract.get_description ();
    }

    public override void activate () {
        try {
            contract.execute_with_file (file);
        } catch (Error err) {
            warning (err.message);
        }
    }
}
