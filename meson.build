project(
    'io.elementary.code',
    'vala', 'c',
    meson_version: '>= 0.58.0',
    version: '8.1.2'
)

add_project_arguments([
        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name())
    ],
    language: 'c',
)

add_project_arguments(
    ['--vapidir', meson.project_source_root() / 'vapi'],
    language: 'vala'
)

if get_option('have_pkexec')
    add_project_arguments('--define=HAVE_PKEXEC', language: 'vala')
endif

libexecdir = get_option('prefix') / get_option('libexecdir') / meson.project_name()
pluginsdir = get_option('prefix') / get_option('libdir') / meson.project_name() / 'plugins'

gnome = import('gnome')
i18n = import('i18n')

glib_dep = dependency('glib-2.0', version: '>=2.74.0')
gio_unix_dep = dependency('gio-unix-2.0', version: '>=2.20')
gee_dep = dependency('gee-0.8', version: '>=0.8.5')
gtk_dep = dependency('gtk+-3.0', version: '>=3.6.0')
granite_dep = dependency('granite', version: '>=6.0.0')
handy_dep = dependency('libhandy-1', version: '>=0.90.0')
gtksourceview_dep = dependency('gtksourceview-4')
peas_dep = dependency('libpeas-2')
git_dep = dependency('libgit2-glib-1.0', version: '>=1.2.0')
fontconfig_dep = dependency('fontconfig')
pangofc_dep = dependency('pangoft2')
posix_dep = meson.get_compiler('vala').find_library('posix')
vte_dep = dependency('vte-2.91')

code_resources = gnome.compile_resources(
    'code-resources', 'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data'
)

# We need libvala-X.XX library, but it changes depending on the version that is installed
vala_version = run_command (meson.get_compiler('vala'), '--api-version', check: true).stdout().strip()
vala_dep = dependency('libvala-@0@'.format(vala_version))

dependencies = [
    glib_dep,
    gio_unix_dep,
    gee_dep,
    gtk_dep,
    granite_dep,
    handy_dep,
    gtksourceview_dep,
    peas_dep,
    git_dep,
    fontconfig_dep,
    pangofc_dep,
    posix_dep,
    vala_dep,
    vte_dep
]

git = find_program('git', required: false)
branch = ''
if get_option('development') and git.found ()
    output = run_command('git','branch','--show-current', check: false)
    branch = output.stdout().strip()
endif

# Profiler linking code taken from https://github.com/RidgeRun/gst-inference/blob/master/meson.build
# with some amendments
# 'libprofiler' and 'libtcmalloc' are provided by installing (e.g.) 'google-perftools' and 'libgoogle-pertools-dev'
# Profiling is not active unless either the correct environment variables are set at runtime
# or the profiling is switched on/off in the code using the CPU_PROFILING and HEAP_PROFILING conditional compilation flags
# with the commands Profiler.start (<path-to-profile-output>) and Profiler.stop () and the corresponding HeapProfiler functions
# It is advisable not to run cpu profiling at the same time as heap profiling
# If meson options are changed then rebuild with 'cd .. && sudo rm -R ./build && build'
# See https://github.com/gperftools/gperftools/blob/master/docs/cpuprofile.adoc
# and https://github.com/gperftools/gperftools/blob/master/docs/heapprofile.adoc
if get_option('cpu-profiling-enabled')
  profiler_dep = dependency ('libprofiler')
  if(profiler_dep.found())
    message('CPU profiling enabled: Building with profiling support.')
    add_global_link_arguments ('-lprofiler', language: 'c')
    add_project_arguments ('--define=PROFILING', language: 'vala')
    dependencies += profiler_dep
  else
    message('MESON_FAIL: CPU profiling requested but libprofiler (gperftools) not found.')
  endif
endif
if get_option('heap-profiling-enabled')
  heap_profiler_dep = dependency ('libtcmalloc')
  if(heap_profiler_dep.found())
    message('Heap profiling enabled: Building with heap profiling support.')
    add_global_link_arguments ('-ltcmalloc', language: 'c')
    add_project_arguments ('--define=HEAP_PROFILING', language: 'vala')
    dependencies += heap_profiler_dep
  else
    message('MESON_FAIL: Heap profiling requested but libtcmalloc (gperftools) not found.')
  endif
endif


subdir('data')
subdir('src')
if get_option('plugins')
    subdir('plugins')
endif
subdir('po')

gnome.post_install(glib_compile_schemas: true)
