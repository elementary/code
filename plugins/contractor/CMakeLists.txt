add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
    contractor.vala
PACKAGES
    scratch
    granite
    gtksourceview-3.0
    scratchcore
    gee-1.0
    libpeas-1.0
    zeitgeist-1.0
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(scratchcontractor MODULE ${VALA_C})
add_dependencies(scratchcontractor scratchcore scratch)
install(TARGETS scratchcontractor DESTINATION lib/scratch/plugins/contractor/)
install(FILES contractor.plugin DESTINATION lib/scratch/plugins/contractor/)
