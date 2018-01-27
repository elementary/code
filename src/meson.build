library_files = files(
    'Services/PluginManager.vala',
    'Services/TemplateManager.vala',
    'Services/Document.vala'
)

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
    'Services/TemplateManager.vala',
    'Services/PluginManager.vala',
    'Services/Settings.vala',
    'Services/FileHandler.vala',
    'Services/ZeitgeistLogger.vala',
    'Services/Document.vala',
    'Widgets/SplitView.vala',
    'Widgets/WelcomeView.vala',
    'Widgets/DocumentView.vala',
    'Widgets/SourceView.vala',
    'Widgets/HeaderBar.vala',
    'Widgets/Pane.vala',
    'Widgets/SearchBar.vala',
    'Widgets/PaneSwitcher.vala',
    'Widgets/FormatBar.vala'
)

executable(
    meson.project_name(),
    code_files,
    library_files,
    config_header,
    dependencies: dependencies,
    install: true
)

# We declare a dependency to be used by plugins
elementary_code_dep = declare_dependency(
    sources: [
        library_files,
        config_header
    ],
    dependencies: dependencies,
    include_directories: [include_directories('.')]
)
