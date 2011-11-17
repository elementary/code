find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.11.3" MINIMUM)
include(ValaPrecompile)
find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED scratch scratchcore gtksourceview-3.0)
add_definitions(${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER})
link_directories(${DEPS_LIBRARY_DIRS})
vala_precompile(VALA_C
    contractor.vala
PACKAGES
    scratch
    granite
    scratchplugins
    gtksourceview-3.0
    scratchcore
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(scratchcontractor MODULE ${VALA_C})
install(TARGETS scratchcontractor DESTINATION lib/scratch/plugins/core/)
install(FILES contractor.plug DESTINATION lib/scratch/plugins/core/)
