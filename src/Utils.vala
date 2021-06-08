// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*
* Copyright (c) 2013 Mario Guerriero <mefrio.g@gmail.com>
*               2017 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Scratch.Utils {
    public string? last_path = null;

    public SimpleAction action_from_group (string action_name, SimpleActionGroup action_group) {
        return ((SimpleAction) action_group.lookup_action (action_name));
    }

    /* Ported (with corrections and improvements) from libdazzle
     * (https://gitlab.gnome.org/GNOME/libdazzle/-/blob/master/src/util/dzl-pango.c)
     */
    public string pango_font_description_to_css (Pango.FontDescription font_descr) {
        var sb = new StringBuilder ("");
        var mask = font_descr.get_set_fields ();
        if (Pango.FontMask.FAMILY in mask) {
            unowned string family = font_descr.get_family ();
            sb.append_printf ("font-family: \"%s\";", family);
        }

        if (Pango.FontMask.STYLE in mask) {
            var style = font_descr.get_style ();

            switch (style) {
                case Pango.Style.NORMAL:
                    sb.append ("font-style: normal;");
                    break;

                case Pango.Style.ITALIC:
                    sb.append ("font-style: italic;");
                    break;

                case Pango.Style.OBLIQUE:
                    sb.append ("font-style: bold;");
                    break;

                default:
                    break;
            }
        }

        if (Pango.FontMask.VARIANT in mask) {
            var variant = font_descr.get_variant ();
            switch (variant) {
                case Pango.Variant.NORMAL:
                    sb.append ("font-variant: normal;");
                    break;

                case Pango.Variant.SMALL_CAPS:
                    sb.append ("font-variant: small-caps");
                    break;

                default:
                    break;
            }
        }

        if (Pango.FontMask.WEIGHT in mask) {
            var weight = ((int)(font_descr.get_weight () / 100 * 100)).clamp (100, 900);

            sb.append_printf ("font-weight: %i;", weight);
        }

        if (Pango.FontMask.STRETCH in mask) {
            var stretch = font_descr.get_stretch ();

            switch (stretch) {
                case Pango.Stretch.NORMAL:
                    sb.append_printf ("font-stretch: %s;", "normal");
                    break;

                case Pango.Stretch.ULTRA_CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "condensed");
                    break;

                case Pango.Stretch.EXTRA_CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "extra-condensed");
                    break;

                case Pango.Stretch.CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "condensed");
                    break;

                case Pango.Stretch.SEMI_CONDENSED:
                    sb.append_printf ("font-stretch: %s;", "normal");
                    break;

                case Pango.Stretch.SEMI_EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "semi-expanded");
                    break;

                case Pango.Stretch.EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "expanded");
                    break;

                case Pango.Stretch.EXTRA_EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "extra-expanded");
                    break;

                case Pango.Stretch.ULTRA_EXPANDED:
                    sb.append_printf ("font-stretch: %s;", "ultra-expanded");
                    break;

                default:
                    break;

            }
        }

        if (Pango.FontMask.SIZE in mask) {
            var font_size = font_descr.get_size () / Pango.SCALE;
            sb.append_printf ("font-size: %dpt;", font_size);
        }

        return sb.str;
    }
}
