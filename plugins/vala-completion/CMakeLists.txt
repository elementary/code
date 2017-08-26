add_definitions (${NORMAL_CFLAGS})
include_directories (${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories (${NORMAL_LINK_DIRS})

set (PLUGIN_NAME "vala-completion")

add_definitions (${VTE_CFLAGS})
link_libraries (${VTE_LIBRARIES})
link_directories (${VTE_LIBRARY_DIRS})

pkg_check_modules (VALA_COMP libvala-0.34 webkit2gtk-4.0)
add_definitions (${VALA_COMP_CFLAGS})
link_libraries (${VALA_COMP_LIBRARIES})
link_directories (${VALA_COMP_LIBRARY_DIRS})

vala_precompile(VALA_C ${PLUGIN_NAME}
    CompletionPlugin.vala
    ValaDocumentProvider.vala
    ValaDefinitionWriter.vala
    ValaBlockLocator.vala
    ValaCodeParser.vala
    Location.vala
    CodeParser.vala
    Report.vala
    SymbolDocumentationView.vala
PACKAGES
    granite
    gtksourceview-3.0
    webkit2gtk-4.0
    scratchcore
    gee-0.8
    libvala-0.34
    libpeas-1.0
    ${ZEITGEIST_DEPS}
OPTIONS
    ${DEFAULT_PLUGIN_OPTIONS}
)

glib_compile_resources (GLIB_RESOURCES_VALACOMPLETION SOURCE icons/vala-completion.gresource.xml)

add_library(${PLUGIN_NAME} MODULE ${VALA_C} ${GLIB_RESOURCES_VALACOMPLETION})
add_dependencies(${PLUGIN_NAME} ${LIBNAME})

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})

message("-- Vala Completion plugin will be compiled")
