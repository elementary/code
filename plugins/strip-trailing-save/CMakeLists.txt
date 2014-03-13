add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

vala_precompile(VALA_C
    strip-trailing-save.vala
PACKAGES
    granite
    gtksourceview-3.0
    scratchcore
    gee-0.8
    libpeas-1.0
    ${ZEITGEIST_DEPS}
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(strip-trailing-save MODULE ${VALA_C})
add_dependencies(strip-trailing-save scratchcore scratch)
install(TARGETS strip-trailing-save DESTINATION lib/scratch/plugins/strip-trailing-save/)
install(FILES strip-trailing-save.plugin DESTINATION lib/scratch/plugins/strip-trailing-save/)
message("-- StripTrailSave plugin will be compiled")
