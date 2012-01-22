find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.11.3" MINIMUM)
include(ValaPrecompile)
find_package(PkgConfig)
pkg_check_modules(DEPS_PASTEBIN REQUIRED libsoup-2.4 libpeas-1.0 granite gee-1.0 gtksourceview-3.0)
add_definitions(${DEPS_PASTEBIN_CFLAGS} ${DEPS_PASTEBIN_CFLAGS_OTHER})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/libplugins/ ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${DEPS_PASTEBIN_LIBRARY_DIRS})
vala_precompile(VALA_C
    pastebin.vala
    pastebin_dialog.vala
PACKAGES
    scratch
    libsoup-2.4
    granite
    scratchplugins
    gtksourceview-3.0
    scratchcore
    gee-1.0
    libpeas-1.0
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
    --vapidir=${CMAKE_BINARY_DIR}/libplugins/
)
add_library(scratchpastebin MODULE ${VALA_C})
add_dependencies(scratchpastebin scratchcore scratch)

target_link_libraries (scratchpastebin ${DEPS_PASTEBIN_LIBRARIES})

install(TARGETS scratchpastebin DESTINATION lib/scratch/plugins/pastebin/)
install(FILES pastebin.plugin DESTINATION lib/scratch/plugins/pastebin/)
