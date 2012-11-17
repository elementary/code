pkg_check_modules (DEVHELP REQUIRED "libdevhelp-3.0")
if (${DEVHELP_FOUND})
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${DEVHELP_CFLAGS})
link_libraries (${DEVHELP_LIBRARIES})
link_directories (${DEVHELP_LIBRARY_DIRS})

set (VALAFLAGS "")
pkg_check_modules(DEVHELP36 QUIET libdevhelp-3.0>=3.5)
if (DEVHELP36_FOUND)
	set (VALAFLAGS "--define=HAS_DEVHELP36")
endif (DEVHELP36_FOUND)

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
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
    ${VALAFLAGS}
)
add_library(devhelp MODULE ${VALA_C})
add_dependencies(devhelp scratchcore scratch)
install(TARGETS devhelp DESTINATION lib/scratch/plugins/devhelp/)
install(FILES devhelp.plugin DESTINATION lib/scratch/plugins/devhelp/)
message("-- DevHelp plugin will be compiled")
else()
message("-- DevHelp plugin will NOT be compiled")
endif()
