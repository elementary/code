/*  
 * SPDX-License-Identifier: GPL-3.0-or-later  
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>  
 *
 * Authored by: Colin Kiama <colinkiama@gmail.com>
 */

public class RestoreOverride : GLib.Object {
    public GLib.File file { get; construct; }
    public SelectionRange range { get; construct; }

    public RestoreOverride (GLib.File file, SelectionRange range) {
        Object (
            file: file,
            range: range
        );
    }
}
