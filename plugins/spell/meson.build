module_name = 'spell'

module_files = [
    'spell.vala'
]

spell_dep = dependency('gtkspell3-3.0')

module_deps = [
    codecore_dep,
    spell_dep
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
