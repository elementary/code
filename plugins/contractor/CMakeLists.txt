OPTION(WITH_CONTRACTOR "Add Contractor support" ON)
if(WITH_CONTRACTOR)
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
    contractor.vala
PACKAGES
    granite
    gtksourceview-3.0
    scratchcore
    gee-1.0
    libpeas-1.0
    zeitgeist-1.0
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(contractor MODULE ${VALA_C})
add_dependencies(contractor scratchcore scratch)
install(TARGETS contractor DESTINATION lib/scratch/plugins/contractor/)
install(FILES contractor.plugin DESTINATION lib/scratch/plugins/contractor/)
message("-- Contractor plugin will be compiled")
else()
message("-- Contractor plugin will NOT be compiled")
endif(WITH_CONTRACTOR)
