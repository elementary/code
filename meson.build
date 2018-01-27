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
gee_dep = dependency('gee-0.8', version: '>=0.8.5')
gtk_dep = dependency('gtk+-3.0', version: '>=3.6.0')
granite_dep = dependency('granite')
gtksourceview_dep = dependency('gtksourceview-3.0')
peas_dep = dependency('libpeas-1.0')
peasgtk_dep = dependency('libpeas-gtk-1.0')
posix_dep = meson.get_compiler('vala').find_library('posix')

dependencies = [
    glib_dep,
    gee_dep,
    gtk_dep,
    granite_dep,
    gtksourceview_dep,
    peas_dep,
    peasgtk_dep,
    posix_dep,
]

subdir('data')
subdir('src')
if get_option('plugins')
    subdir('plugins')
endif
subdir('po')
