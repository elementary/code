add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
	SourceTreePlugin.vala
PACKAGES
    gtk+-3.0
    gee-1.0
    granite
    scratchcore
    libpeas-1.0
    gtksourceview-3.0
    zeitgeist-1.0
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(source-tree MODULE ${VALA_C})
target_link_libraries(source-tree ${NORMAL_LIBRARIES})
install(TARGETS source-tree DESTINATION lib/scratch/plugins/source-tree/)
install(FILES source-tree.plugin DESTINATION lib/scratch/plugins/source-tree/)
add_dependencies(source-tree scratchcore scratch)
message("-- Source Tree plugin will be compiled")
