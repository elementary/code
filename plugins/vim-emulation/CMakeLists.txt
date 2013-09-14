add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

vala_precompile(VALA_C
    vim-emulation.vala
PACKAGES
    vte-2.90
    granite
    gtksourceview-3.0
    scratchcore
    gee-1.0
    libpeas-1.0
    zeitgeist-2.0
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(vim-emulation MODULE ${VALA_C})
add_dependencies(vim-emulation scratchcore scratch)
install(TARGETS vim-emulation DESTINATION lib/scratch/plugins/vim-emulation/)
install(FILES vim-emulation.plugin DESTINATION lib/scratch/plugins/vim-emulation/)
message("-- Vim Emulation plugin will be compiled")
