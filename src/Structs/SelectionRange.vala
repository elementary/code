public struct SelectionRange {
    public int start_line;
    public int start_column;
    public int end_line;
    public int end_column;

    public const SelectionRange EMPTY = {0, 0, 0, 0};
}
