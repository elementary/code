module_name = 'browser-preview'

module_files = [
    'browser-preview.vala',
    'BrowserView.vala'
]

webkit_dep = dependency('webkit2gtk-4.0')

module_deps = [
    codecore_dep,
    webkit_dep,
]

shared_module(
    module_name,
    module_files,
    dependencies: module_deps,
    install: true,
    install_dir: join_paths(pluginsdir, module_name),
)

i18n.merge_file(
    input: module_name + '.plugin',
    output: module_name + '.plugin',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    type: 'desktop',
    install_dir: join_paths(pluginsdir, module_name),
    install: true
)
