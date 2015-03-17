add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
    CtagsSymbolResolver.vala
    OutlinePlugin.vala
    ValaProcessing/ComparisonHelper.vala
    ValaProcessing/SymbolItem.vala
    ValaProcessing/SymbolOutline.vala
    ValaProcessing/SymbolResolver.vala
    SymbolOutline.vala
PACKAGES
    gtk+-3.0
    gee-0.8
    granite
    scratchcore
    libpeas-1.0
    gtksourceview-3.0
    ${ZEITGEIST_DEPS}
    libvala-${VALA_SHORTVER}
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
    --target-glib=2.32
)

include (GResource)
glib_compile_resources (GLIB_RESOURCES_OUTLINE SOURCE icons/outline.gresource.xml)

pkg_check_modules(OUTLINE_DEPS libvala-${VALA_SHORTVER})
link_directories(${OUTLINE_DEPS_LIBRARY_DRIS})
add_definitions(${OUTLINE_DEPS_CFLAGS})

add_library(outline MODULE ${VALA_C} ${GLIB_RESOURCES_OUTLINE})
target_link_libraries(outline ${NORMAL_LIBRARIES} ${OUTLINE_DEPS_LIBRARIES})
install(TARGETS outline DESTINATION lib/scratch/plugins/outline/)
install(FILES outline.plugin DESTINATION lib/scratch/plugins/outline/)
add_dependencies(outline scratchcore scratch)

message("-- Outline plugin will be compiled")
