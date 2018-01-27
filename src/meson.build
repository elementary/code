conf_data = configuration_data()
conf_data.set_quoted('PROJECT_NAME', meson.project_name())
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('VERSION', meson.project_version())
conf_data.set_quoted('PREFIX', get_option('prefix'))
conf_data.set_quoted('PLUGINDIR', pluginsdir)
config_header = configure_file(
    input : 'config.vala.in',
    output : 'config.vala',
    configuration : conf_data
)

code_files = files(
    'Application.vala',
    'DrawSpacesUtils.vala',
    'MainWindow.vala',
    'Utils.vala',
    'Dialogs/PreferencesDialog.vala',
    'Services/Document.vala',
    'Services/FileHandler.vala',
    'Services/PluginManager.vala',
    'Services/Settings.vala',
    'Services/TemplateManager.vala',
    'Services/ZeitgeistLogger.vala',
    'Widgets/DocumentView.vala',
    'Widgets/FormatBar.vala',
    'Widgets/HeaderBar.vala',
    'Widgets/Pane.vala',
    'Widgets/PaneSwitcher.vala',
    'Widgets/SearchBar.vala',
    'Widgets/SourceView.vala',
    'Widgets/SplitView.vala',
    'Widgets/WelcomeView.vala',
)

executable(
    meson.project_name(),
    code_files,
    config_header,
    dependencies: dependencies,
    install: true
)

library(
    'codecore',
    code_files,
    config_header,
    dependencies: dependencies,
    install: true,
    install_dir: [true, true, true]
)
