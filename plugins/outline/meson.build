module_name = 'outline'

module_files = [
    'CtagsSymbolResolver.vala',
    'OutlinePane.vala',
    'OutlinePlugin.vala',
    'SymbolOutline.vala',
    'ValaProcessing/ComparisonHelper.vala',
    'ValaProcessing/SymbolItem.vala',
    'ValaProcessing/SymbolOutline.vala',
    'ValaProcessing/SymbolResolver.vala'
]

vala_dep = dependency('libvala-0.40', required: false)
if vala_dep.found () != true
    vala_dep = dependency('libvala-0.36', required: true)
endif

module_deps = [
    codecore_dep,
    vala_dep
]

icons_gresource = gnome.compile_resources('gresource_icons', 'icons/outline.gresource.xml', source_dir: 'icons')

shared_module(
    module_name,
    module_files,
    icons_gresource,
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
               '-d' + join_paths(meson.source_root (), 'po', 'plugins'),
               '--template=@INPUT@',
               '-o@OUTPUT@',
               ],
    install : true,
    install_dir: join_paths(pluginsdir, module_name),
)
