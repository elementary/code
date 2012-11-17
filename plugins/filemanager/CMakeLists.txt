pkg_check_modules(DEPS_FM marlincore gail-3.0)
if(${DEPS_FM_FOUND})
add_definitions(${NORMAL_CFLAGS} ${DEPS_FM_CFLAGS} ${DEPS_FM_CFLAGS_OTHER})
link_directories(${NORMAL_LINK_DIRS} ${DEPS_FM_LIBRARY_DIRS})
vala_precompile(VALA_C
        filemanager.vala
        marlincore.vala
    PACKAGES
        gtk+-3.0
        gee-1.0
        scratch
        granite
        marlincore
        scratchcore
        libpeas-1.0
        gtksourceview-3.0
        zeitgeist-1.0
    OPTIONS
        --vapidir=${CMAKE_BINARY_DIR}
    	--vapidir=${CMAKE_BINARY_DIR}/src/
        --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
    )
add_library(filemanager MODULE ${VALA_C})
target_link_libraries(filemanager ${NORMAL_LIBRARIES} ${DEPS_FM_LIBRARIES})
install(TARGETS filemanager DESTINATION lib/scratch/plugins/fm/)
install(FILES filemanager.plugin DESTINATION lib/scratch/plugins/fm/)
add_dependencies(filemanager scratchcore scratch)
message("-- Filemanager plugin will be compiled")
else()
message("-- Filemanager plugin will NOT be compiled")
endif()
