add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

pkg_check_modules (VTE REQUIRED "vte-2.90")
add_definitions (${VTE_CFLAGS})
link_libraries (${VTE_LIBRARIES})
link_directories (${VTE_LIBRARY_DIRS})

vala_precompile(VALA_C
    terminal.vala
PACKAGES
    vte-2.90
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
)
add_library(scratchterminal MODULE ${VALA_C})
add_dependencies(scratchterminal scratchcore scratch)
install(TARGETS scratchterminal DESTINATION lib/scratch/plugins/terminal/)
install(FILES terminal.plugin DESTINATION lib/scratch/plugins/terminal/)
