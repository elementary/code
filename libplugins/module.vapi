[CCode (cprefix = "G", lower_case_cprefix = "g_")]
namespace GLib {
    [CCode (cheader_filename = "gmodule.h")]
    public class Module : Object
    {
        public static Module open(string path, ModuleFlags flags);
        public static string error();
        public bool symbol(string name, out void* func);
        public string name();
    }
    
    [CCode (cheader_filename = "gmodule.h", cprefix = "G_MODULE_")]
    public enum ModuleFlags
    {
        BIND_LOCAL
    }
}