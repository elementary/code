shared_module(
    'brackets-completion',
    'brackets-completion.vala',
    dependencies: codecore_dep,
    install: true,
    install_dir: join_paths(pluginsdir, 'brackets-completion'),
)

i18n.merge_file(
    input: 'brackets-completion.plugin.in',
    output: 'brackets-completion.plugin',
    po_dir: join_paths(meson.source_root (), 'po', 'extra'),
    type: 'desktop',
    install_dir: join_paths(pluginsdir, 'brackets-completion'),
    install: true
)
