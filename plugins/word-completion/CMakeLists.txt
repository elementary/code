find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.18" MINIMUM)
include(ValaPrecompile)
find_package(PkgConfig)

pkg_check_modules(DEPS REQUIRED
 gtksourceview-3.0
 scratchcore
 libpeas-1.0
)

add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

vala_precompile(VALA_C
    plugin.vala
    completion-provider.vala
    engine.vala
PACKAGES
    granite
    gtksourceview-3.0
    scratchcore
    libpeas-1.0
OPTIONS
)

add_library(scratchwordcompletion MODULE ${VALA_C})

install(TARGETS scratchwordcompletion DESTINATION lib/scratch/plugins/scratch/)
install(FILES word-completion.plugin DESTINATION lib/scratch/plugins/scratch/)