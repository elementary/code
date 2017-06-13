add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})

set (PLUGIN_NAME "folder-manager")

vala_precompile(VALA_C ${PLUGIN_NAME}
    FolderManagerPlugin.vala
    File.vala
    FileView.vala
    Item.vala
    Settings.vala
PACKAGES
    gtk+-3.0
    gee-0.8
    granite
    scratchcore
    libpeas-1.0
    gtksourceview-3.0
    ${ZEITGEIST_DEPS}
OPTIONS
    ${DEFAULT_PLUGIN_OPTIONS}
)

add_library(${PLUGIN_NAME} MODULE ${VALA_C})
add_dependencies(${PLUGIN_NAME} ${LIBNAME})

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})

message("-- Folder Manager plugin will be compiled")
