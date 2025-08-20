[CCode (cheader_filename = "gperftools/profiler.h")]
namespace Profiler {
    [CCode (cname = "ProfilerStart")]
    public static void start (string path_to_output_file);
    [CCode (cname = "ProfilerStop")]
    public static void stop ();
    [CCode (cname = "ProfilerFlush")]
    public static void flush ();
}
