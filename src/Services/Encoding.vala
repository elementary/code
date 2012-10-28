// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE  

  Copyright (C) 2012 Mario Guerriero <mefrio.g@gmail.com>
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

namespace Scratch.Services {

    public enum EncodingType {

        ISO_8859_1,
        ISO_8859_2,
        ISO_8859_3,
        ISO_8859_4,
        ISO_8859_5,
        ISO_8859_6,
        ISO_8859_7,
        ISO_8859_8,
        ISO_8859_9,
        ISO_8859_10,
        ISO_8859_13,
        ISO_8859_14,
        ISO_8859_15,
        ISO_8859_16,

        UTF_7,
        UTF_16,
        UTF_16_BE,
        UTF_16_LE,
        UTF_32,
        UCS_2,
        UCS_4,

        ARMSCII_8,
        BIG5,
        BIG5_HKSCS,
        CP_866,

        EUC_JP,
        EUC_JP_MS,
        CP932,
        EUC_KR,
        EUC_TW,

        GB18030,
        GB2312,
        GBK,
        GEOSTD8,

        IBM_850,
        IBM_852,
        IBM_855,
        IBM_857,
        IBM_862,
        IBM_864,

        ISO_2022_JP,
        ISO_2022_KR,
        ISO_IR_111,
        JOHAB,
        KOI8_R,
        KOI8__R,
        KOI8_U,

        SHIFT_JIS,
        TCVN,
        TIS_620,
        UHC,
        VISCII,

        WINDOWS_1250,
        WINDOWS_1251,
        WINDOWS_1252,
        WINDOWS_1253,
        WINDOWS_1254,
        WINDOWS_1255,
        WINDOWS_1256,
        WINDOWS_1257,
        WINDOWS_1258,

        LAST,

        UTF_8,
        UNKNOWN

    }

    public struct Encoding {
        public EncodingType type;
        public string? encoding;
        public string? name;
    }

    public static const Encoding[] encodings = {

        { EncodingType.ISO_8859_1,
            "ISO-8859-1", N_("Western") },
        { EncodingType.ISO_8859_2,
         "ISO-8859-2", N_("Central European") },
        { EncodingType.ISO_8859_3,
            "ISO-8859-3", N_("South European") },
        { EncodingType.ISO_8859_4,
            "ISO-8859-4", N_("Baltic") },
        { EncodingType.ISO_8859_5,
            "ISO-8859-5", N_("Cyrillic") },
        { EncodingType.ISO_8859_6,
            "ISO-8859-6", N_("Arabic") },
        { EncodingType.ISO_8859_7,
            "ISO-8859-7", N_("Greek") },
        { EncodingType.ISO_8859_8,
            "ISO-8859-8", N_("Hebrew Visual") },
        { EncodingType.ISO_8859_9,
            "ISO-8859-9", N_("Turkish") },
        { EncodingType.ISO_8859_10,
            "ISO-8859-10", N_("Nordic") },
        { EncodingType.ISO_8859_13,
            "ISO-8859-13", N_("Baltic") },
        { EncodingType.ISO_8859_14,
            "ISO-8859-14", N_("Celtic") },
        { EncodingType.ISO_8859_15,
            "ISO-8859-15", N_("Western") },
        { EncodingType.ISO_8859_16,
            "ISO-8859-16", N_("Romanian") },

        { EncodingType.UTF_7,
            "UTF-7", N_("Unicode") },
        { EncodingType.UTF_16,
            "UTF-16", N_("Unicode") },
        { EncodingType.UTF_16_BE,
            "UTF-16BE", N_("Unicode") },
        { EncodingType.UTF_16_LE,
            "UTF-16LE", N_("Unicode") },
        { EncodingType.UTF_32,
            "UTF-32", N_("Unicode") },
        { EncodingType.UCS_2,
            "UCS-2", N_("Unicode") },
        { EncodingType.UCS_4,
            "UCS-4", N_("Unicode") },

        { EncodingType.ARMSCII_8,
            "ARMSCII-8", N_("Armenian") },
        { EncodingType.BIG5,
            "BIG5", N_("Chinese Traditional") },
        { EncodingType.BIG5_HKSCS,
            "BIG5-HKSCS", N_("Chinese Traditional") },
        { EncodingType.CP_866,
            "CP866", N_("Cyrillic/Russian") },

        { EncodingType.EUC_JP,
            "EUC-JP", N_("Japanese") },
        { EncodingType.EUC_JP_MS,
            "EUC-JP-MS", N_("Japanese") },
        { EncodingType.CP932,
            "CP932", N_("Japanese") },

        { EncodingType.EUC_KR,
            "EUC-KR", N_("Korean") },
        { EncodingType.EUC_TW,
            "EUC-TW", N_("Chinese Traditional") },

        { EncodingType.GB18030,
            "GB18030", N_("Chinese Simplified") },
        { EncodingType.GB2312,
            "GB2312", N_("Chinese Simplified") },
        { EncodingType.GBK,
            "GBK", N_("Chinese Simplified") },
        { EncodingType.GEOSTD8,
            "GEORGIAN-ACADEMY", N_("Georgian") }, /* FIXME GEOSTD8 ? */

        { EncodingType.IBM_850,
            "IBM850", N_("Western") },
        { EncodingType.IBM_852,
            "IBM852", N_("Central European") },
        { EncodingType.IBM_855,
            "IBM855", N_("Cyrillic") },
        { EncodingType.IBM_857,
            "IBM857", N_("Turkish") },
        { EncodingType.IBM_862,
            "IBM862", N_("Hebrew") },
        { EncodingType.IBM_864,
            "IBM864", N_("Arabic") },

        { EncodingType.ISO_2022_JP,
            "ISO-2022-JP", N_("Japanese") },
        { EncodingType.ISO_2022_KR,
            "ISO-2022-KR", N_("Korean") },
        { EncodingType.ISO_IR_111,
            "ISO-IR-111", N_("Cyrillic") },
        { EncodingType.JOHAB,
            "JOHAB", N_("Korean") },
        { EncodingType.KOI8_R,
            "KOI8R", N_("Cyrillic") },
        { EncodingType.KOI8__R,
            "KOI8-R", N_("Cyrillic") },
        { EncodingType.KOI8_U,
            "KOI8U", N_("Cyrillic/Ukrainian") },

        { EncodingType.SHIFT_JIS,
            "SHIFT_JIS", N_("Japanese") },
        { EncodingType.TCVN,
            "TCVN", N_("Vietnamese") },
        { EncodingType.TIS_620,
            "TIS-620", N_("Thai") },
        { EncodingType.UHC,
            "UHC", N_("Korean") },
        { EncodingType.VISCII,
            "VISCII", N_("Vietnamese") },

        { EncodingType.WINDOWS_1250,
            "WINDOWS-1250", N_("Central European") },
        { EncodingType.WINDOWS_1251,
            "WINDOWS-1251", N_("Cyrillic") },
        { EncodingType.WINDOWS_1252,
            "WINDOWS-1252", N_("Western") },
        { EncodingType.WINDOWS_1253,
            "WINDOWS-1253", N_("Greek") },
        { EncodingType.WINDOWS_1254,
            "WINDOWS-1254", N_("Turkish") },
        { EncodingType.WINDOWS_1255,
            "WINDOWS-1255", N_("Hebrew") },
        { EncodingType.WINDOWS_1256,
            "WINDOWS-1256", N_("Arabic") },
        { EncodingType.WINDOWS_1257,
            "WINDOWS-1257", N_("Baltic") },
        { EncodingType.WINDOWS_1258,
            "WINDOWS-1258", N_("Vietnamese") }
    };
    
    public string? file_content_to_utf8 (File file, string content, string mode = "a") {
        
        GLib.IOChannel channel;
        string? encoding = null;
        string? encoded_content = null;
        
        try {
            channel = new GLib.IOChannel.file (file.get_path (), mode);
            encoding = channel.get_encoding ();
            debug (file.get_basename () + " encoding: " + encoding);
        } catch (FileError e) {
            warning (e.message);
        }
        
        if (encoding != null && encoding != "UTF-8") {
            try {
                encoded_content = convert (content, -1, "UTF-8", encoding);
            } catch (GLib.ConvertError ce) {
                warning (ce.message);
                encoded_content = null;
            }
        }
        
        return encoded_content;
    
    }

}
