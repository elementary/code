/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2023 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Marvin Ahlgrimm
 */

public class SearchResult {
    public string full_path;
    public string relative_path;
    public string project;
    public bool found;
    public int score;

    public SearchResult (bool fo, int sc) {
        full_path = "";
        relative_path = "";
        project = "";
        found = fo;
        score = sc;
    }
}
