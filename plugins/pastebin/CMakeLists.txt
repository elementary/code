pkg_check_modules(DEPS_PASTEBIN libsoup-2.4)
if(${DEPS_PASTEBIN_FOUND})
add_definitions(${NORMAL_CFLAGS} ${DEPS_PASTEBIN_CFLAGS} ${DEPS_PASTEBIN_CFLAGS_OTHER})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS} ${DEPS_PASTEBIN_LIBRARY_DIRS})
vala_precompile(VALA_C
    pastebin.vala
    pastebin_dialog.vala
PACKAGES
    libsoup-2.4
    granite
    gtksourceview-3.0
    scratchcore
    gee-0.8
    libpeas-1.0
    ${ZEITGEIST_DEPS}
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(pastebin MODULE ${VALA_C})
add_dependencies(pastebin scratchcore scratch)
target_link_libraries (pastebin ${NORMAL_LIBRARIES} ${DEPS_PASTEBIN_LIBRARIES})
install(TARGETS pastebin DESTINATION lib/scratch/plugins/pastebin/)
install(FILES pastebin.plugin DESTINATION lib/scratch/plugins/pastebin/)
add_dependencies(pastebin scratchcore scratch)
message("-- Pastebin plugin will be compiled")
else()
message("-- Pastebin plugin will NOT be compiled")
endif()
