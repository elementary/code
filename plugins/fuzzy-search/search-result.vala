public class SearchResult {
    public string full_path;
    public string relative_path;
    public bool found;
    public int score;

    public SearchResult (bool fo, int sc) {
        full_path = "";
        relative_path = "";
        found = fo;
        score = sc;
    }
}