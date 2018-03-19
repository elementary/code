icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps')
    )
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i + '@2', 'apps')
    )
endforeach

install_data(
    'io.elementary.code.gschema.xml',
    'io.elementary.code.plugins.spell.gschema.xml',
    'io.elementary.code.plugins.terminal.gschema.xml',
    install_dir: join_paths(get_option('prefix'), get_option('datadir'), 'glib-2.0', 'schemas')
)

config_data = configuration_data()
config_data.set('EXEC_NAME', meson.project_name())

# Set the executable name and translate the desktop files
desktop_in_file = configure_file(
    input: 'io.elementary.code.desktop.in.in',
    output: '@BASENAME@',
    configuration: config_data
)

desktop_file = i18n.merge_file(
    input: desktop_in_file,
    output: 'io.elementary.code.desktop',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    type: 'desktop',
    install_dir: join_paths(get_option('datadir'), 'applications'),
    install: true
)

# Translate the AppData file
appstream_file = i18n.merge_file(
    input: 'io.elementary.code.appdata.xml.in',
    output: '@BASENAME@',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    install_dir: join_paths(get_option('datadir'), 'metainfo'),
    install: true
)
