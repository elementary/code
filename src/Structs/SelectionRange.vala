public struct SelectionRange {
    public int start_line;
    public int start_column;
    public int end_line;
    public int end_column;

    public static SelectionRange empty = {0, 0, 0, 0};
}