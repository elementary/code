// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE  

  Copyright (C) 2012-2013 Mario Guerriero <mario@elementaryos.org>
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

// TODO: do it using native Vala code dropping the python script

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
            "ISO-8859-1", "Western" },
        { EncodingType.ISO_8859_2,
         "ISO-8859-2", "Central European" },
        { EncodingType.ISO_8859_3,
            "ISO-8859-3", "South European" },
        { EncodingType.ISO_8859_4,
            "ISO-8859-4", "Baltic" },
        { EncodingType.ISO_8859_5,
            "ISO-8859-5", "Cyrillic" },
        { EncodingType.ISO_8859_6,
            "ISO-8859-6", "Arabic" },
        { EncodingType.ISO_8859_7,
            "ISO-8859-7", "Greek" },
        { EncodingType.ISO_8859_8,
            "ISO-8859-8", "Hebrew Visual" },
        { EncodingType.ISO_8859_9,
            "ISO-8859-9", "Turkish" },
        { EncodingType.ISO_8859_10,
            "ISO-8859-10", "Nordic" },
        { EncodingType.ISO_8859_13,
            "ISO-8859-13", "Baltic" },
        { EncodingType.ISO_8859_14,
            "ISO-8859-14", "Celtic" },
        { EncodingType.ISO_8859_15,
            "ISO-8859-15", "Western" },
        { EncodingType.ISO_8859_16,
            "ISO-8859-16", "Romanian" },

        { EncodingType.UTF_7,
            "UTF-7", "Unicode" },
        { EncodingType.UTF_16,
            "UTF-16", "Unicode" },
        { EncodingType.UTF_16_BE,
            "UTF-16BE", "Unicode" },
        { EncodingType.UTF_16_LE,
            "UTF-16LE", "Unicode" },
        { EncodingType.UTF_32,
            "UTF-32", "Unicode" },
        { EncodingType.UCS_2,
            "UCS-2", "Unicode" },
        { EncodingType.UCS_4,
            "UCS-4", "Unicode" },

        { EncodingType.ARMSCII_8,
            "ARMSCII-8", "Armenian" },
        { EncodingType.BIG5,
            "BIG5", "Chinese Traditional" },
        { EncodingType.BIG5_HKSCS,
            "BIG5-HKSCS", "Chinese Traditional" },
        { EncodingType.CP_866,
            "CP866", "Cyrillic/Russian" },

        { EncodingType.EUC_JP,
            "EUC-JP", "Japanese" },
        { EncodingType.EUC_JP_MS,
            "EUC-JP-MS", "Japanese" },
        { EncodingType.CP932,
            "CP932", "Japanese" },

        { EncodingType.EUC_KR,
            "EUC-KR", "Korean" },
        { EncodingType.EUC_TW,
            "EUC-TW", "Chinese Traditional" },

        { EncodingType.GB18030,
            "GB18030", "Chinese Simplified" },
        { EncodingType.GB2312,
            "GB2312", "Chinese Simplified" },
        { EncodingType.GBK,
            "GBK", "Chinese Simplified" },
        { EncodingType.GEOSTD8,
            "GEORGIAN-ACADEMY", "Georgian" }, /* FIXME GEOSTD8 ? */

        { EncodingType.IBM_850,
            "IBM850", "Western" },
        { EncodingType.IBM_852,
            "IBM852", "Central European" },
        { EncodingType.IBM_855,
            "IBM855", "Cyrillic" },
        { EncodingType.IBM_857,
            "IBM857", "Turkish" },
        { EncodingType.IBM_862,
            "IBM862", "Hebrew" },
        { EncodingType.IBM_864,
            "IBM864", "Arabic" },

        { EncodingType.ISO_2022_JP,
            "ISO-2022-JP", "Japanese" },
        { EncodingType.ISO_2022_KR,
            "ISO-2022-KR", "Korean" },
        { EncodingType.ISO_IR_111,
            "ISO-IR-111", "Cyrillic" },
        { EncodingType.JOHAB,
            "JOHAB", "Korean" },
        { EncodingType.KOI8_R,
            "KOI8R", "Cyrillic" },
        { EncodingType.KOI8__R,
            "KOI8-R", "Cyrillic" },
        { EncodingType.KOI8_U,
            "KOI8U", "Cyrillic/Ukrainian" },

        { EncodingType.SHIFT_JIS,
            "SHIFT_JIS", "Japanese" },
        { EncodingType.TCVN,
            "TCVN", "Vietnamese" },
        { EncodingType.TIS_620,
            "TIS-620", "Thai" },
        { EncodingType.UHC,
            "UHC", "Korean" },
        { EncodingType.VISCII,
            "VISCII", "Vietnamese" },

        { EncodingType.WINDOWS_1250,
            "WINDOWS-1250", "Central European" },
        { EncodingType.WINDOWS_1251,
            "WINDOWS-1251", "Cyrillic" },
        { EncodingType.WINDOWS_1252,
            "WINDOWS-1252", "Western" },
        { EncodingType.WINDOWS_1253,
            "WINDOWS-1253", "Greek" },
        { EncodingType.WINDOWS_1254,
            "WINDOWS-1254", "Turkish" },
        { EncodingType.WINDOWS_1255,
            "WINDOWS-1255", "Hebrew" },
        { EncodingType.WINDOWS_1256,
            "WINDOWS-1256", "Arabic" },
        { EncodingType.WINDOWS_1257,
            "WINDOWS-1257", "Baltic" },
        { EncodingType.WINDOWS_1258,
            "WINDOWS-1258", "Vietnamese" }
    };
    
    private static bool test (string text, string charset) {
          bool valid = false;

        try {
            string convert;

            convert = GLib.convert (text, -1, "UTF-8", charset);
            valid = true;
        }
        catch (Error e) {
            debug (e.message);
        }
        return valid;
    }
    
    public static string get_charset (string path) {
        // Get correct encoding via chardect.py script

        const string FALLBACK_CHARSET = "UTF-8";
        string script = Constants.SCRIPTDIR + "/chardetect.py";
        string command = "python " + script + " \"" + path.replace ("\\ ", " ") + "\"";
        string? charset = null;

        try {
            GLib.Process.spawn_command_line_sync (command, out charset);
        } catch (SpawnError e) {
            warning ("Could not execute \"%s\": %s", script, e.message);
        }
        if ( charset == null ) {
            warning ("Could not automatically detect encoding, assuming %s", FALLBACK_CHARSET);
            charset = FALLBACK_CHARSET; //TODO: prompt the user to meddle with encoding manually, until satisfied
        } else {
            debug ("Detected encoding of file \"%s\" to be \"%s\"", path, charset);
        }
        return charset;
    }
   
    public string? file_content_to_utf8 (File file, string content, string mode = "r" /* it means read or write */) {
        
        string? encoding = null;
        string? encoded_content = null;
        
        encoding = get_charset (file.get_path ());
        
        try {
			InputStream @is = file.read ();
			CharsetConverter iconverter = new CharsetConverter ("utf-8", encoding.down());
			ConverterInputStream @converted = new ConverterInputStream(@is, iconverter);
			DataInputStream dis = new DataInputStream (@converted);
			string line = dis.read_line ();
			string str = line;
			while ((line = dis.read_line (null)) != null) {
				str += line + "\n";
			}
			encoded_content = str;
        } catch (GLib.ConvertError ce) {
            warning (ce.message);
        } catch (IOError e){
			stdout.printf ("IOError: %s\n", e.message);
		} catch (Error e){
			stdout.printf ("IOError: %s\n", e.message);
		}
                
        return encoded_content;
    
    }

}
