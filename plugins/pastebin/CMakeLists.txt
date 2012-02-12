pkg_check_modules(DEPS_PASTEBIN libsoup-2.4)
if(${DEPS_PASTEBIN_FOUND})
add_definitions(${NORMAL_CFLAGS} ${DEPS_PASTEBIN_CFLAGS} ${DEPS_PASTEBIN_CFLAGS_OTHER})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS} ${DEPS_PASTEBIN_LIBRARY_DIRS})
vala_precompile(VALA_C
        pastebin.vala
        pastebin_dialog.vala
    PACKAGES
        scratch
        libsoup-2.4
        granite
        gtksourceview-3.0
        scratchcore
        gee-1.0
        libpeas-1.0
    OPTIONS
        --vapidir=${CMAKE_BINARY_DIR}
        --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
    )
add_library(scratchpastebin MODULE ${VALA_C})
add_dependencies(scratchpastebin scratchcore scratch)
target_link_libraries (scratchpastebin ${NORMAL_LIBRARIES} ${DEPS_PASTEBIN_LIBRARIES})
install(TARGETS scratchpastebin DESTINATION lib/scratch/plugins/pastebin/)
install(FILES pastebin.plugin DESTINATION lib/scratch/plugins/pastebin/)
add_dependencies(scratchpastebin scratchcore scratch)
message("-- File Manager plugin will be compiled")
else()
message("-- File Manager plugin will NOT be compiled")
endif()
