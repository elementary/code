pkg_check_modules(DEPS_PASTEBIN libsoup-2.4)
if(${DEPS_PASTEBIN_FOUND})
add_definitions(${NORMAL_CFLAGS} ${DEPS_PASTEBIN_CFLAGS} ${DEPS_PASTEBIN_CFLAGS_OTHER})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/${LIBNAME}/)
link_libraries (${DEPS_PASTEBIN_LIBRARIES})
link_directories(${NORMAL_LINK_DIRS} ${DEPS_PASTEBIN_LIBRARY_DIRS})

set (PLUGIN_NAME "pastebin")

vala_precompile(VALA_C ${PLUGIN_NAME}
    pastebin.vala
    pastebin_dialog.vala
PACKAGES
    libsoup-2.4
    granite
    gtksourceview-3.0
    ${LIBNAME}
    gee-0.8
    libpeas-1.0
    ${ZEITGEIST_DEPS}
OPTIONS
    ${DEFAULT_PLUGIN_OPTIONS}
)

add_library(${PLUGIN_NAME} MODULE ${VALA_C})
add_dependencies(${PLUGIN_NAME} ${LIBNAME})

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
message("-- Pastebin plugin will be compiled")
else()
message("-- Pastebin plugin will NOT be compiled")
endif()
