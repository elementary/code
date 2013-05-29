add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
    ProjectManager.vala
    File.vala
    Settings.vala
    FileView.vala
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
add_library(project-manager MODULE ${VALA_C})
target_link_libraries(project-manager ${NORMAL_LIBRARIES})
install(TARGETS project-manager DESTINATION lib/scratch/plugins/project-manager/)
install(FILES project-manager.plugin DESTINATION lib/scratch/plugins/project-manager/)
add_dependencies(project-manager scratchcore scratch)
message("-- Project Manager plugin will be compiled")
