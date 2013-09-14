pkg_check_modules (VTE REQUIRED "vte-2.90")
if (${VTE_FOUND})
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${VTE_CFLAGS})
link_libraries (${VTE_LIBRARIES})
link_directories (${VTE_LIBRARY_DIRS})

vala_precompile(VALA_C
    terminal.vala
PACKAGES
    vte-2.90
    granite
    gtksourceview-3.0
    scratchcore
    gee-1.0
    libpeas-1.0
    zeitgeist-2.0
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(terminal MODULE ${VALA_C})
add_dependencies(terminal scratchcore scratch)
install(TARGETS terminal DESTINATION lib/scratch/plugins/terminal/)
install(FILES terminal.plugin DESTINATION lib/scratch/plugins/terminal/)
message("-- Terminal plugin will be compiled")
else()
message("-- Terminal plugin will NOT be compiled")
endif()
