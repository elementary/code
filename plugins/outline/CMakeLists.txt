add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})
vala_precompile(VALA_C
	OutlinePlugin.vala
	ValaSymbolResolver.vala
	ValaComparisonHelper.vala
	CtagsSymbolResolver.vala
PACKAGES
    gtk+-3.0
    gee-1.0
    granite
    scratchcore
    libpeas-1.0
    gtksourceview-3.0
    zeitgeist-2.0
	libvala-${VALA_SHORTVER}
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore/
    -D GLIB_2_32
)

pkg_check_modules(OUTLINE_DEPS libvala-${VALA_SHORTVER})
link_directories(${OUTLINE_DEPS_LIBRARY_DRIS})
add_definitions(${OUTLINE_DEPS_CFLAGS})

add_library(outline MODULE ${VALA_C})
target_link_libraries(outline ${NORMAL_LIBRARIES} ${OUTLINE_DEPS_LIBRARIES})
install(TARGETS outline DESTINATION lib/scratch/plugins/outline/)
install(FILES outline.plugin DESTINATION lib/scratch/plugins/outline/)
add_dependencies(outline scratchcore scratch)

set(SYSTEM_DEFAULT_THEME ${CMAKE_INSTALL_PREFIX}/share/icons/hicolor)
install(FILES icons/class-symbolic.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/scalable/actions)
install(FILES icons/constant-symbolic.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/scalable/actions)
install(FILES icons/enum-symbolic.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/scalable/actions)
install(FILES icons/field-symbolic.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/scalable/actions)
install(FILES icons/interface-symbolic.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/scalable/actions)
install(FILES icons/property-symbolic.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/scalable/actions)
install(FILES icons/signal-symbolic.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/scalable/actions)
install(FILES icons/structure-symbolic.svg DESTINATION ${SYSTEM_DEFAULT_THEME}/scalable/actions)

message("-- Outline plugin will be compiled")
