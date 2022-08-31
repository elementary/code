// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2022 elementary LLC. (https://elementary.io),
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3
 * as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
 */

 public class Scratch.Services.DocumentManager : Object {
    static Gee.HashMultiMap <string, string> project_restorable_docs_map;
    static Gee.HashMultiMap <string, string> project_open_docs_map;

    static DocumentManager? instance;
    public static DocumentManager get_instance () {
         if (instance == null) {
             instance = new DocumentManager ();
         }

         return instance;
     }

    static construct {
        project_restorable_docs_map = new Gee.HashMultiMap<string, string> ();
        project_open_docs_map = new Gee.HashMultiMap<string, string> ();
    }

    public void make_restorable (Document doc) {
        project_restorable_docs_map.@set (doc.source_view.project.path, doc.file.get_path ());
    }

    public void add_open_document (Document doc) {
        if (doc.source_view.project == null) {
            return;
        }

        project_open_docs_map.@set (doc.source_view.project.path, doc.file.get_path ());
    }

    public void remove_open_document (Document doc) {
        if (doc.source_view.project == null) {
            return;
        }

        project_open_docs_map.remove (doc.source_view.project.path, doc.file.get_path ());
    }

    public void remove_project (string project_path) {
        project_restorable_docs_map.remove_all (project_path);
    }

    public Gee.Collection<string> take_restorable_paths (string project_path) {
        var docs = project_restorable_docs_map.@get (project_path);
        project_restorable_docs_map.remove_all (project_path);
        return docs;
    }

    public uint restorable_for_project (string project_path) {
        return project_restorable_docs_map.@get (project_path).size;
    }

    public uint open_for_project (string project_path) {
        return project_open_docs_map.@get (project_path).size;
    }
 }
