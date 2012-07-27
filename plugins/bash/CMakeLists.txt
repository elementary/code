add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

pkg_check_modules (VTE REQUIRED "vte-2.90")
add_definitions (${VTE_CFLAGS})
link_libraries (${VTE_LIBRARIES})
link_directories (${VTE_LIBRARY_DIRS})

vala_precompile(VALA_C
    bash.vala
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
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(scratchbash MODULE ${VALA_C})
add_dependencies(scratchbash scratchcore scratch)
install(TARGETS scratchbash DESTINATION lib/scratch/plugins/bash/)
install(FILES bash.plugin DESTINATION lib/scratch/plugins/bash/)
