/*-
 * Copyright (c) 2015-2016 Adam Bieńkowski
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Adam Bieńkowski <donadigos159@gmail.com>
 */

public abstract class CodeParser : Object {
    public abstract void parse ();
    public abstract void add_document (Scratch.Services.Document document);
    public abstract void remove_document (Scratch.Services.Document document);
    public abstract ReportMessage? get_report_message_at (string? filename, int line);

    protected ThreadPool<void*> parse_pool;

    construct {
        try {
            parse_pool = new ThreadPool<void*>.with_owned_data (parse, 1, true);
        } catch (ThreadError e) {
            warning (e.message);
        }                
    }

    public virtual void queue_parse () {
        try {
            parse_pool.add ((void*)1);
        } catch (ThreadError e) {
            warning (e.message);
        }
    }

    public virtual signal void begin_parsing () {

    }

    public virtual signal void end_parsing () {
        
    }
}
