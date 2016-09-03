pkg_check_modules (VTE "vte-2.91")
if (NOT VTE_FOUND)
pkg_check_modules (VTE REQUIRED "vte-2.90")
endif()

if (${VTE_FOUND})
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${VTE_CFLAGS})
link_libraries (${VTE_LIBRARIES})
link_directories (${VTE_LIBRARY_DIRS})

set (PLUGIN_NAME "terminal")

if (${VTE_VERSION} VERSION_LESS "0.38.0")
vala_precompile(VALA_C ${PLUGIN_NAME}
    Settings.vala
    terminal.vala
PACKAGES
    vte-2.90
    granite
    gtksourceview-3.0
    scratchcore
    gee-0.8
    libpeas-1.0
    ${ZEITGEIST_DEPS}
OPTIONS
    ${DEFAULT_PLUGIN_OPTIONS}
)
else()
vala_precompile(VALA_C ${PLUGIN_NAME}
    Settings.vala
    terminal.vala
PACKAGES
    vte-2.91
    granite
    gtksourceview-3.0
    scratchcore
    gee-0.8
    libpeas-1.0
    ${ZEITGEIST_DEPS}
OPTIONS
    ${DEFAULT_PLUGIN_OPTIONS}
    --define=VTE291
)
endif()
add_library(${PLUGIN_NAME} MODULE ${VALA_C})
add_dependencies(${PLUGIN_NAME} ${LIBNAME})

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
message("-- Terminal plugin will be compiled")
else()
message("-- Terminal plugin will NOT be compiled")
endif()
