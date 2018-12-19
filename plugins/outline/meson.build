module_name = 'outline'

module_files = [
    'C/CtagsSymbol.vala',
    'C/CtagsSymbolIter.vala',
    'C/CtagsSymbolOutline.vala',
    'OutlinePane.vala',
    'OutlinePlugin.vala',
    'SymbolOutline.vala',
    'Vala/ValaComparisonHelper.vala',
    'Vala/ValaSymbolItem.vala',
    'Vala/ValaSymbolOutline.vala',
    'Vala/ValaSymbolResolver.vala'
]

# We need libvala-X.XX library, but it changes depending on the version that is installed
vala_version = run_command (meson.get_compiler('vala'), '--api-version').stdout().strip()
vala_dep = dependency('libvala-@0@'.format(vala_version))

module_deps = [
    codecore_dep,
    vala_dep
]

icons_gresource = gnome.compile_resources('gresource_icons', 'outline.gresource.xml', source_dir: join_paths(meson.source_root (), 'plugins', 'outline', 'icons'))

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
