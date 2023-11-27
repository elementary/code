/*  
 * SPDX-License-Identifier: GPL-3.0-or-later  
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>  
 *
 * Authored by: Colin Kiama <colinkiama@gmail.com>
 */

public struct SelectionRange {
    public int start_line;
    public int start_column;
    public int end_line;
    public int end_column;

    public const SelectionRange EMPTY = {0, 0, 0, 0};
}
