project('io.elementary.code', 'vala', 'c', version: '2.4.1')

add_project_arguments([
        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name())
    ],
    language: 'c',
)

libexecdir = join_paths(get_option('prefix'), get_option('libexecdir'), meson.project_name())
pluginsdir = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name(), 'plugins')

gnome = import('gnome')
i18n = import('i18n')

glib_dep = dependency('glib-2.0', version: '>=2.30.0')
gio_unix_dep = dependency('gio-unix-2.0', version: '>=2.20')
gee_dep = dependency('gee-0.8', version: '>=0.8.5')

dependencies = [
    glib_dep,
    gio_unix_dep,
    gee_dep,
]

subdir('data')
subdir('src')
if get_option('plugins')
    subdir('plugins')
endif
subdir('po')
