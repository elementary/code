pkg_check_modules (SPELL REQUIRED "gtkspell-3.0")
if (${SPELL_FOUND})
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${SPELL_CFLAGS})
link_libraries (${SPELL_LIBRARIES})
link_directories (${SPELL_LIBRARY_DIRS})

vala_precompile(VALA_C
    spell-check.vala
PACKAGES
    gtkspell-3.0
    scratch
    gtk+-3.0
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
    ${VALAFLAGS}
)
add_library(spellcheck MODULE ${VALA_C})
add_dependencies(spellcheck scratchcore scratch)
install(TARGETS spellcheck DESTINATION lib/scratch/plugins/terminal/)
install(FILES spell-check.plugin DESTINATION lib/scratch/plugins/terminal/)
message("-- Spell check plugin will be compiled")
else()
message("-- Spell check plugin will NOT be compiled")
endif()
