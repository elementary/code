pkg_check_modules (WEBKIT REQUIRED "webkitgtk-3.0")
if(${WEBKIT_FOUND})
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${WEBKIT_CFLAGS})
link_libraries (${WEBKIT_LIBRARIES})
link_directories (${WEBKIT_LIBRARY_DIRS})

set (PLUGIN_NAME "browser-preview")

vala_precompile(VALA_C ${PLUGIN_NAME}
    browser-preview.vala
    BrowserView.vala
PACKAGES
    webkitgtk-3.0
    granite
    gtksourceview-3.0
    scratchcore
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

message("-- Browser preview plugin will be compiled")
else()
message("-- Browser preview plugin will NOT be compiled")
endif()
