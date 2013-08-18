pkg_check_modules (SPELLLEGACY QUIET "gtkspell-3.0")
pkg_check_modules (SPELL QUIET "gtkspell3-3.0")

if(SPELLLEGACY_FOUND)
set(SPELLPACKAGE "gtkspell-3.0")
set(VALAFLAGS "${VALAFLAGS} -DSPELLLEGACY")
elseif(SPELL_FOUND)
set(SPELLPACKAGE "gtkspell3-3.0")
endif()

if (SPELLLEGACY_FOUND OR SPELL_FOUND)
pkg_check_modules (SPELL REQUIRES ${SPELLPACKAGE})
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${SPELL_CFLAGS})
link_libraries (${SPELL_LIBRARIES})
link_directories (${SPELL_LIBRARY_DIRS})

vala_precompile(VALA_C
    spell.vala
PACKAGES
    ${SPELLPACKAGE}
    gtk+-3.0
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
    ${VALAFLAGS}
)
add_library(spell MODULE ${VALA_C})
add_dependencies(spell scratchcore scratch)
install(TARGETS spell DESTINATION lib/scratch/plugins/spell/)
install(FILES spell.plugin DESTINATION lib/scratch/plugins/spell/)
message("-- Spell check plugin will be compiled")
else()
message("-- Spell check plugin will NOT be compiled")
endif()
