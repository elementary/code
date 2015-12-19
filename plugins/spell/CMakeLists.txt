pkg_check_modules (SPELLLEGACY QUIET "gtkspell-3.0")
pkg_check_modules (SPELL QUIET "gtkspell3-3.0")

if(SPELLLEGACY_FOUND)
set(SPELLPACKAGE "gtkspell-3.0")
set(SPELLLEGACY_FLAGS "--define=SPELLLEGACY")
elseif(SPELL_FOUND)
set(SPELLPACKAGE "gtkspell3-3.0")
set(SPELLLEGACY_FLAGS "")
endif()

if (SPELLLEGACY_FOUND OR SPELL_FOUND)
pkg_check_modules (SPELL REQUIRED ${SPELLPACKAGE})
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${SPELL_CFLAGS})
link_libraries (${SPELL_LIBRARIES})
link_directories (${SPELL_LIBRARY_DIRS})

set (PLUGIN_NAME "spell")

vala_precompile(VALA_C ${PLUGIN_NAME}
    spell.vala
    Settings.vala
PACKAGES
    ${SPELLPACKAGE}
    gtk+-3.0
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
    ${VALAFLAGS}
    ${SPELLLEGACY_FLAGS}
)
add_library(${PLUGIN_NAME} MODULE ${VALA_C})
add_dependencies(${PLUGIN_NAME} ${LIBNAME} scratch)

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
message("-- Spell check plugin will be compiled")
else()
message("-- Spell check plugin will NOT be compiled")
endif()
