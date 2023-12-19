public class SearchResult {
    public string full_path;
    public string relative_path;
    public string project;
    public bool found;
    public int score;

    public SearchResult (bool fo, int sc) {
        full_path = "";
        relative_path = "";
        project = "";
        found = fo;
        score = sc;
    }
}
