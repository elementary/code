pkg_check_modules (VTE "vte-2.91")
if (NOT VTE_FOUND)
pkg_check_modules (VTE REQUIRED "vte-2.90")
endif()

if (${VTE_FOUND})
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${VTE_CFLAGS})
link_libraries (${VTE_LIBRARIES})
link_directories (${VTE_LIBRARY_DIRS})

if (${VTE_VERSION} VERSION_LESS "0.38.0")
vala_precompile(VALA_C
    terminal.vala
PACKAGES
    vte-2.90
    granite
    gtksourceview-3.0
    scratchcore
    gee-0.8
    libpeas-1.0
    ${ZEITGEIST_DEPS}
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
else()
vala_precompile(VALA_C
    terminal.vala
PACKAGES
    vte-2.91
    granite
    gtksourceview-3.0
    scratchcore
    gee-0.8
    libpeas-1.0
    ${ZEITGEIST_DEPS}
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
    --define=VTE291
)
endif()
add_library(terminal MODULE ${VALA_C})
add_dependencies(terminal scratchcore scratch)
install(TARGETS terminal DESTINATION lib/scratch/plugins/terminal/)
install(FILES terminal.plugin DESTINATION lib/scratch/plugins/terminal/)
message("-- Terminal plugin will be compiled")
else()
message("-- Terminal plugin will NOT be compiled")
endif()
