add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/${LIBNAME}/)
link_directories(${NORMAL_LINK_DIRS})

set (PLUGIN_NAME "open-with")

vala_precompile(VALA_C ${PLUGIN_NAME}
    open-with.vala
PACKAGES
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
message("-- Open With plugin will be compiled")
