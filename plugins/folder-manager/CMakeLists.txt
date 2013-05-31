add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
    FolderManagerPlugin.vala
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
add_library(folder-manager MODULE ${VALA_C})
target_link_libraries(folder-manager ${NORMAL_LIBRARIES})
install(TARGETS folder-manager DESTINATION lib/scratch/plugins/folder-manager/)
install(FILES folder-manager.plugin DESTINATION lib/scratch/plugins/folder-manager/)
add_dependencies(folder-manager scratchcore scratch)
message("-- Folder Manager plugin will be compiled")
