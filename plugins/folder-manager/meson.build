module_name = 'folder-manager'

module_files = [
    'File.vala',
    'FileItem.vala',
    'FileView.vala',
    'FolderItem.vala',
    'FolderManagerPlugin.vala',
    'Item.vala',
    'MainFolderItem.vala',
    'Settings.vala',
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
