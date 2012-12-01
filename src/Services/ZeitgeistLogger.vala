// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2012 Manish Sinha <manishsinha@ubuntu.com>
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

using Zeitgeist;

namespace Scratch.Services {

    public class ZeitgeistLogger {

        Zeitgeist.Log zg_log = new Zeitgeist.Log();

        string actor = "application://scratch.desktop";
        string event_manifestation = ZG_USER_ACTIVITY;

        public void open_insert (string? uri, string mimetype) {
            
            if (uri == null)
                return;
            
            var subject = get_subject(uri, mimetype);
            var event = new Event.full (ZG_ACCESS_EVENT,
                                event_manifestation,
                                actor,
                                subject, null);

            insert_events(event);
        }

        public void close_insert (string? uri, string mimetype) {
            
            if (uri == null) 
                return;
            
            var subject = get_subject(uri, mimetype);
            var event = new Event.full (ZG_LEAVE_EVENT,
                                event_manifestation,
                                actor,
                                subject, null);

            insert_events(event);
       }

        public void save_insert (string uri, string mimetype) {

            var subject = get_subject(uri, mimetype);
            var event = new Event.full (ZG_MODIFY_EVENT,
                                event_manifestation,
                                actor,
                                subject, null);

            insert_events(event);
        }

        public void move_insert (string old_uri, string new_uri, string mimetype) {

            var subject = get_subject(old_uri, mimetype);
            subject.set_current_uri(new_uri);
            var event = new Event.full (ZG_MOVE_EVENT,
                                event_manifestation,
                                actor,
                                subject, null);

            insert_events(event);
        }

        private void insert_events (Zeitgeist.Event ev) {
            zg_log.insert_events_no_reply (ev, null);
        }

        private Subject get_subject(string uri, string mimetype) {

            return new Subject.full (uri,
                          interpretation_for_mimetype (mimetype),
                          manifestation_for_uri (uri),
                          mimetype,
                          GLib.Path.get_dirname(uri),
                          GLib.Path.get_basename(uri),
                          ""); // FIXME: storage?!
        }
    }

}

