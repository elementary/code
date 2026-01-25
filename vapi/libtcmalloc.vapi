[CCode (cheader_filename = "gperftools/heap-profiler.h")]
namespace HeapProfiler {
    [CCode (cname = "HeapProfilerStart")]
    public static void start (string path_to_output_file_profix);
    [CCode (cname = "HeapProfilerStop")]
    public static void stop ();
    [CCode (cname = "HeapProfilerDump")]
    public static void dump (string reason);
}
