add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

vala_precompile(VALA_C
    strip-trailing-save.vala
PACKAGES
    scratch
    granite
    gtksourceview-3.0
    scratchcore
    gee-1.0
    libpeas-1.0
    zeitgeist-1.0
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
