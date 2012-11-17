pkg_check_modules (WEBKIT REQUIRED "webkitgtk-3.0")
if(${WEBKIT_FOUND})
add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

add_definitions (${WEBKIT_CFLAGS})
link_libraries (${WEBKIT_LIBRARIES})
link_directories (${WEBKIT_LIBRARY_DIRS})

vala_precompile(VALA_C
    browser-preview.vala
PACKAGES
    webkitgtk-3.0
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
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(browserpreview MODULE ${VALA_C})
add_dependencies(browserpreview scratchcore scratch)
install(TARGETS browserpreview DESTINATION lib/scratch/plugins/browser-preview/)
install(FILES browser-preview.plugin DESTINATION lib/scratch/plugins/browser-preview/)
message("-- Browser preview plugin will be compiled")
else()
message("-- Browser preview plugin will NOT be compiled")
endif()
