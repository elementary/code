namespace Gtk
{
  [CCode (cprefix = "GTKSPELL_ERROR_", cheader_filename = "gtkspell/gtkspell.h")]
  public errordomain SpeelError
  {
    ERROR_BACKEND
  }

  [Compact]
  [CCode (cheader_filename = "gtkspell/gtkspell.h", free_function = "")]
  public class Spell
  {
    [CCode (cname = "gtkspell_new_attach")]
    public Spell.attach (TextView view, string? lang) throws GLib.Error;
    [CCode (cname = "gtkspell_get_from_text_view")]
    public static Spell get_from_text_view (TextView view);
    [CCode (cname = "gtkspell_detach")]
    public void detach ();
    [CCode (cname = "gtkspell_set_language")]
    public bool set_language (string lang) throws GLib.Error;
    [CCode (cname = "gtkspell_recheck_all")]
    public void recheck_all ();
  }
}
