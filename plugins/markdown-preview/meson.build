module_name = 'markdown-preview'

module_files = [
    'markdown-preview.vala',
]

module_deps = [
    codecore_dep,
    dependency('webkit2gtk-4.1'),
    dependency('gee-0.8'),
]

shared_module(
    module_name,
    module_files,
    dependencies: module_deps,
    install: true,
    install_dir: pluginsdir / module_name,
)

custom_target(module_name + '.plugin_merge',
    input: module_name + '.plugin',
    output: module_name + '.plugin',
    command : [msgfmt,
               '--desktop',
               '--keyword=Description',
               '--keyword=Name',
               '-d' + meson.project_source_root () / 'po' / 'plugins',
               '--template=@INPUT@',
               '-o@OUTPUT@',
               ],
    install : true,
    install_dir: pluginsdir / module_name,
)
