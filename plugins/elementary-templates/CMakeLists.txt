add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
    elementary-templates.vala
    granite.vala
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
add_library(elementary-templates MODULE ${VALA_C})
add_dependencies(elementary-templates scratchcore)
add_subdirectory (templates)
install(TARGETS elementary-templates DESTINATION lib/scratch/plugins/elementary-templates/)
install(FILES elementary-templates.plugin DESTINATION lib/scratch/plugins/elementary-templates/)
message("-- elementary Templates plugin will be compiled")
