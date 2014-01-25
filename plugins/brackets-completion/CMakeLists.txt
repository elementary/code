add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

vala_precompile(VALA_C
    brackets-completion.vala
PACKAGES
    granite
    gtksourceview-3.0
    scratchcore
    gee-0.8
    libpeas-1.0
    zeitgeist-2.0
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)

add_library(brackets-completion MODULE ${VALA_C})
add_dependencies(brackets-completion scratchcore scratch)

install(TARGETS brackets-completion DESTINATION lib/scratch/plugins/brackets-completion/)
install(FILES brackets-completion.plugin DESTINATION lib/scratch/plugins/brackets-completion/)

message("-- Brackets completion plugin will be compiled")
