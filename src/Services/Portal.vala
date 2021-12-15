/*
 * Copyright (c) 2021 elementary, Inc. (https://elementary.io)
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

namespace Portal {
    const string DESKTOP_BUS_NAME = "org.freedesktop.portal.Desktop";
    const string DESKTOP_BUS_PATH = "/org/freedesktop/portal/desktop";
    OpenURI? open_uri_portal = null;

    public static string generate_token () {
        return "%s_%i".printf (
            GLib.Application.get_default ().application_id.replace (".", "_"),
            Random.int_range (0, int32.MAX)
        );
    }

    [DBus (name = "org.freedesktop.portal.OpenURI")]
    interface OpenURI : Object {
        [DBus (name = "version")]
        public abstract uint32 version { get; }

        public static OpenURI @get () throws Error {
            if (open_uri_portal == null) {
                var connection = GLib.Application.get_default ().get_dbus_connection ();
                open_uri_portal = connection.get_proxy_sync<OpenURI> (DESKTOP_BUS_NAME, DESKTOP_BUS_PATH);
            }

            return open_uri_portal;
        }

        public abstract ObjectPath open_uri (string parent_window, string uri, HashTable<string, Variant> options) throws DBusError, IOError;
        public abstract ObjectPath open_file (string parent_window, UnixInputStream fd, HashTable<string, Variant> options) throws DBusError, IOError;
        public abstract ObjectPath open_directory (string parent_window, UnixInputStream fd, HashTable<string, Variant> options) throws DBusError, IOError;
    }
}
