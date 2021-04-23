project('com.github.{{ github_username }}.{{ github_repository }}', 'vala', 'c')

# Include the translations module
i18n = import('i18n')

# Set our translation domain
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

gtk_plus_3_dep = dependency('gtk+-3.0')
granite_dep = dependency('granite')

dependencies = [
    gtk_plus_3_dep,
    granite_dep,
]

subdir('src')
subdir('data')
subdir('po')

meson.add_install_script('meson/post_install.py')
