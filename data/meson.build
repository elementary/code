icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        'icons' / i + '.svg',
        install_dir: get_option('datadir') / 'icons' / 'hicolor' / i + 'x' + i / 'apps',
        rename: meson.project_name() + '.svg'
    )
    install_data(
        'icons' / i + '.svg',
        install_dir: get_option('datadir') / 'icons' / 'hicolor' / i + 'x' + i + '@2' / 'apps',
        rename: meson.project_name() + '.svg'
    )
endforeach

install_data([
  'styles/elementary-dark.xml',
  'styles/elementary-light.xml',
], install_dir: get_option('datadir') / 'gtksourceview-4' / 'styles')

install_data([
  'fonts/BuilderBlocks.ttf',
], install_dir: get_option('datadir') / meson.project_name() / 'fonts')

install_data(
    'io.elementary.code.gschema.xml',
    'io.elementary.code.plugins.spell.gschema.xml',
    rename: ['com.github.jeremypw.code-testing.gschema.xml', 'com.github.jeremypw.code-testing.plugins.spell.gschema.xml'],
    install_dir: get_option('prefix') / get_option('datadir') / 'glib-2.0' / 'schemas'
)

config_data = configuration_data()
config_data.set('EXEC_NAME', meson.project_name())

if (branch != '')
    config_data.set('NAME', 'Code - ' + branch)
else
    config_data.set('NAME', 'Code')
endif

# Set the executable name and translate the desktop files
desktop_in_file = configure_file(
    input: 'io.elementary.code.desktop.in.in',
    output: '@BASENAME@',
    configuration: config_data
)

desktop_file = i18n.merge_file(
    input: desktop_in_file,
    output: meson.project_name() + '.desktop',
    po_dir: meson.project_source_root () / 'po' / 'extra',
    type: 'desktop',
    install_dir: get_option('datadir') / 'applications',
    install: true
)

i18n.merge_file(
    input: 'code.metainfo.xml.in',
    output: meson.project_name() + '.metainfo.xml',
    po_dir: meson.project_source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: get_option('datadir') / 'metainfo',
)

config_data = configuration_data()
config_data.set('install_prefix', get_option('prefix'))
config_data.set('bin_dir', get_option('bindir'))
config_data.set('exec_name', meson.project_name())

if get_option ('have_pkexec')
    policy_in = configure_file(
        input: 'code.policy.in.in',
        output:  meson.project_name() + '.policy.in',
        configuration: config_data,
        install: false,
    )

    i18n.merge_file(
        input: policy_in,
        output: meson.project_name() + '.policy',
        po_dir: meson.project_source_root () / 'po' / 'extra',
        install: true,
        install_dir: get_option('datadir') / 'polkit-1' / 'actions',
    )
endif

install_man(
    'io.elementary.code.1'
)
