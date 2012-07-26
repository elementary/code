add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

pkg_check_modules (DEVHELP REQUIRED "libdevhelp-3.0")
add_definitions (${DEVHELP_CFLAGS})
link_libraries (${DEVHELP_LIBRARIES})
link_directories (${DEVHELP_LIBRARY_DIRS})

vala_precompile(VALA_C
    devhelp.vala
PACKAGES
    libdevhelp-3.0
    scratch
    granite
    gtksourceview-3.0
    scratchcore
    gee-1.0
    libpeas-1.0
    zeitgeist-1.0
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(scratchdevhelp MODULE ${VALA_C})
add_dependencies(scratchdevhelp scratchcore scratch)
install(TARGETS scratchdevhelp DESTINATION lib/scratch/plugins/devhelp/)
install(FILES devhelp.plugin DESTINATION lib/scratch/plugins/devhelp/)
