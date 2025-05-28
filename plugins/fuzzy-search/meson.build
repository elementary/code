module_name = 'fuzzy-search'

module_files = [
    'file-item.vala',
    'fuzzy-search.vala',
    'fuzzy-finder.vala',
    'fuzzy-search-indexer.vala',
    'fuzzy-search-popover.vala',
    'fuzzy-search-project.vala',
    'search-result.vala',
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

custom_target(module_name + '.plugin_merge',
    input: module_name + '.plugin',
    output: module_name + '.plugin',
    command : [msgfmt,
               '--desktop',
               '--keyword=Description',
               '--keyword=Name',
               '-d' + join_paths(meson.project_source_root (), 'po', 'plugins'),
               '--template=@INPUT@',
               '-o@OUTPUT@',
               ],
    install : true,
    install_dir: join_paths(pluginsdir, module_name),
)
