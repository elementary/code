OPTION(WITH_CONTRACTOR "Add Contractor support" ON)
if(WITH_CONTRACTOR)
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})
set (PLUGIN_NAME "contractor")

vala_precompile(VALA_C ${PLUGIN_NAME}
    contractor.vala
PACKAGES
    granite
    gtksourceview-3.0
    scratchcore
    gee-0.8
    libpeas-1.0
    ${ZEITGEIST_DEPS}
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)

add_library(${PLUGIN_NAME} MODULE ${VALA_C})
add_dependencies(${PLUGIN_NAME} ${LIBNAME} scratch)

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})

message("-- Contractor plugin will be compiled")
else()
message("-- Contractor plugin will NOT be compiled")
endif(WITH_CONTRACTOR)
