[CCode (cheader_filename = "gperftools/profiler.h")]
namespace Profiler {
    [CCode (cname = "ProfilerStart")]
    public static void start (string output);
    [CCode (cname = "ProfilerStop")]
    public static void stop ();
}
