conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', install_name)
conf_data.set_quoted('GETTEXT_PACKAGE', install_name)
conf_data.set_quoted('VERSION', meson.project_version())
conf_data.set_quoted('PREFIX', get_option('prefix'))
conf_data.set_quoted('PLUGINDIR', pluginsdir)
conf_data.set_quoted('DATADIR', get_option('prefix') / get_option('datadir'))
conf_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
conf_data.set_quoted('BRANCH', branch)

config_header = configure_file(
    input : 'config.vala.in',
    output : 'config.vala',
    configuration : conf_data
)

code_files = files(
    'Application.vala',
    'MainWindow.vala',
    'Utils.vala',
    'Dialogs/PreferencesDialog.vala',
    'Dialogs/RestoreConfirmationDialog.vala',
    'Dialogs/GlobalSearchDialog.vala',
    'Dialogs/NewBranchDialog.vala',
    'FolderManager/File.vala',
    'FolderManager/FileItem.vala',
    'FolderManager/FileView.vala',
    'FolderManager/FolderItem.vala',
    'FolderManager/Item.vala',
    'FolderManager/ProjectFolderItem.vala',
    'Services/CommentToggler.vala',
    'Services/Document.vala',
    'Services/DocumentManager.vala',
    'Services/FileHandler.vala',
    'Services/GitManager.vala',
    'Services/LocationJumpManager.vala',
    'Services/MonitoredRepository.vala',
    'Services/PluginManager.vala',
    'Services/RestoreOverride.vala',
    'Services/Settings.vala',
    'Services/TemplateManager.vala',
    'Widgets/ChooseProjectButton.vala',
    'Widgets/DocumentView.vala',
    'Widgets/FormatBar.vala',
    'Widgets/SourceGutterRenderer.vala',
    'Widgets/HeaderBar.vala',
    'Widgets/Sidebar.vala',
    'Widgets/PaneSwitcher.vala',
    'Widgets/SearchBar.vala',
    'Widgets/SourceList/CellRendererBadge.vala',
    'Widgets/SourceList/CellRendererExpander.vala',
    'Widgets/SourceList/SourceList.vala',
    'Widgets/SourceView.vala',
    'Widgets/Terminal.vala',
    'Widgets/WelcomeView.vala',
    'SymbolPane/SymbolOutline.vala',
    'SymbolPane/Vala/ValaComparisonHelper.vala',
    'SymbolPane/Vala/ValaSymbolItem.vala',
    'SymbolPane/Vala/ValaSymbolOutline.vala',
    'SymbolPane/Vala/ValaSymbolResolver.vala',
    'SymbolPane/C/CtagsSymbol.vala',
    'SymbolPane/C/CtagsSymbolIter.vala',
    'SymbolPane/C/CtagsSymbolOutline.vala',
    'Structs/SelectionRange.vala'
)

executable(
    install_name,
    code_files,
    code_resources,
    config_header,
    dependencies: dependencies,
    install: true
)

dogfood_code_core = library(
    'dogfood_code_core',
    code_files,
    config_header,
    dependencies: dependencies,
    install: true,
    install_dir: [true, true, true],
    version: '0.0'
)

pkg = import('pkgconfig')

pkg.generate(
    version: '0.1',
    libraries: dogfood_code_core,
    description: 'experimental Code headers',
    name: 'dogfood_code_core',
    filebase: 'dogfood_code_core'
)

install_data ('dogfood_code_core.deps', install_dir: get_option('prefix') / get_option('datadir') / 'vala' / 'vapi')

dogfood_code_core_dep = declare_dependency(
    link_with: dogfood_code_core,
    dependencies: dependencies,
    include_directories: [include_directories('.')]
)
