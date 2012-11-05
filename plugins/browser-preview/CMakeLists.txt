add_definitions(${NORMAL_CFLAGS})
include_directories(${CMAKE_BINARY_DIR} ${CMAKE_BINARY_DIR}/scratchcore/)
link_directories(${NORMAL_LINK_DIRS})

pkg_check_modules (WEBKIT REQUIRED "webkitgtk-3.0")
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
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
)
add_library(scratchbrowserpreview MODULE ${VALA_C})
add_dependencies(scratchbrowserpreview scratchcore scratch)
install(TARGETS scratchbrowserpreview DESTINATION lib/scratch/plugins/browser-preview/)
install(FILES browser-preview.plugin DESTINATION lib/scratch/plugins/browser-preview/)
