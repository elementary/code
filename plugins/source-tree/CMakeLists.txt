add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})

set (PLUGIN_NAME "source-tree")

vala_precompile(VALA_C ${PLUGIN_NAME}
    SourceTreePlugin.vala
PACKAGES
    gtk+-3.0
    gee-0.8
    granite
    scratchcore
    libpeas-1.0
    gtksourceview-3.0
    ${ZEITGEIST_DEPS}
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(${PLUGIN_NAME} MODULE ${VALA_C})
add_dependencies(${PLUGIN_NAME} ${LIBNAME} scratch)

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
message("-- Source Tree plugin will be compiled")
