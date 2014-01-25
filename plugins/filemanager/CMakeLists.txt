add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
    FileManagerPlugin.vala
    File.vala
    Settings.vala
    FileView.vala
PACKAGES
    gtk+-3.0
    gee-0.8
    granite
    scratchcore
    libpeas-1.0
    gtksourceview-3.0
    zeitgeist-2.0
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(filemanager MODULE ${VALA_C})
target_link_libraries(filemanager ${NORMAL_LIBRARIES})
install(TARGETS filemanager DESTINATION lib/scratch/plugins/filemanager/)
install(FILES filemanager.plugin DESTINATION lib/scratch/plugins/filemanager/)
add_dependencies(filemanager scratchcore scratch)
message("-- File Manager plugin will be compiled")
