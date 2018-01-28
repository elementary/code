module_name = 'highlight-word-selection'

module_files = [
    'highlight-word-selection.vala',
]

module_deps = [
    codecore_dep,
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
    po_dir: join_paths(meson.source_root (), 'po', 'plugins'),
    type: 'desktop',
    install_dir: join_paths(pluginsdir, module_name),
    install: true
)
