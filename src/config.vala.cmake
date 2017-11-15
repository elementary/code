namespace Constants {
   public const string DATADIR = "@DATADIR@";
   public const string SCRIPTDIR = "@SCRIPTDIR@";
   public const string PKGDATADIR = "@PKGDATADIR@";
   public const string GETTEXT_PACKAGE = "@GETTEXT_PACKAGE@";
   public const string PROJECT_NAME = "@CMAKE_PROJECT_NAME@";
   public const string RELEASE_NAME = "@RELEASE_NAME@";
   public const string VERSION = "@VERSION@";
   public const string VERSION_INFO = "@VERSION_INFO@";
   public const string PLUGINDIR = "@PLUGINDIR@";
   public const string INSTALL_PREFIX = "@CMAKE_INSTALL_PREFIX@";

   /* Translatable launcher (.desktop) strings to be added to   */
   /* template (.pot) file. These strings should reflect any    */
   /* changes in these launcher keys in .desktop file.          */
   public const string COMMENT = N_("Edit text files");
   public const string GENERIC = N_("Text Editor");
   public const string NEW_DOCUMENT = N_("New Document");
   public const string NEW_WINDOW = N_("New Window");
   public const string NEW_ROOT_WINDOW = N_("New Window As Administrator");
   public const string ABOUT_SCRATCH = N_("About Scratch");
}
