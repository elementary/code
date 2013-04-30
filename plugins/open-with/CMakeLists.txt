add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
    open-with.vala
PACKAGES
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
add_library(open-with MODULE ${VALA_C})
add_dependencies(open-with scratchcore scratch)
install(TARGETS open-with DESTINATION lib/scratch/plugins/open-with/)
install(FILES open-with.plugin DESTINATION lib/scratch/plugins/open-with/)
message("-- Open With plugin will be compiled")
