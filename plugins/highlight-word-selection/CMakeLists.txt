add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

vala_precompile(VALA_C
    highlight-word-selection.vala
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

add_library(highlight-word-selection MODULE ${VALA_C})
add_dependencies(highlight-word-selection scratchcore scratch)

install(TARGETS highlight-word-selection DESTINATION lib/scratch/plugins/highlight-word-selection/)
install(FILES highlight-word-selection.plugin DESTINATION lib/scratch/plugins/highlight-word-selection/)

message("-- Highlight words plugin will be compiled")
