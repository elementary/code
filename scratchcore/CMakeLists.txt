set (PKGNAME scratchcore)
set (PKGNAME_ SCRATCHCORE)
set (GETTEXT_PACKAGE "scratch")
set (${PKGNAME_}_VERSION 0.1)
# increase when you broke the API

set (${PKGNAME_}_SOVERSION 0)
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
# You hear that? It's kittens being killed by the gods of cmake

configure_file (${CMAKE_CURRENT_SOURCE_DIR}/${PKGNAME}.pc.cmake ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/)
# Link all

add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
set(LIBS
    ${NORMAL_LIBRARIES}
)
set(LIB_PATHS
    ${NORMAL_LINK_DIRS}
)
link_directories(${LIB_PATHS})
#VALA stuff

pkg_check_modules (PEASGTK REQUIRED "libpeas-gtk-1.0")
add_definitions (${PEASGTK_CFLAGS})
link_libraries (${PEASGTK_LIBRARIES})
link_directories (${PEASGTK_LIBRARY_DIRS})

vala_precompile(VALA_C
    main.vala
    SearchManager.vala
    SourceView.vala
    Settings.vala
    PluginManager.vala
    TemplateManager.vala
    FileHandler.vala
PACKAGES
    gtk+-3.0
    granite
    gtksourceview-3.0
    gee-1.0
    libpeas-1.0
    peas-gtk
OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    GENERATE_VAPI
    scratchcore
    GENERATE_HEADER
    scratchcore
)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/scratchcore.vapi DESTINATION ${CMAKE_INSTALL_PREFIX}/share/vala/vapi/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/scratchcore.h DESTINATION ${CMAKE_INSTALL_PREFIX}/include/scratchcore/)
add_library (${PKGNAME} SHARED
    ${VALA_C}
)
if(BUILD_STATIC MATCHES "Yes")
ADD_LIBRARY(${PKGNAME}-static STATIC ${VALA_C})
# The library target "foo" already has a default OUTPUT_NAME of "foo", so we don't need to change it.

# The library target "foo-static" has a default OUTPUT_NAME of "foo-static", so change it.

SET_TARGET_PROPERTIES(${PKGNAME}-static PROPERTIES OUTPUT_NAME ${PKGNAME})
install (TARGETS ${PKGNAME}-static DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
endif(BUILD_STATIC MATCHES "Yes")
set_target_properties (${PKGNAME} PROPERTIES
    VERSION ${SCRATCHCORE_VERSION}
    SOVERSION ${SCRATCHCORE_SOVERSION}
                       )
install (TARGETS ${PKGNAME} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
target_link_libraries(scratchcore ${LIBS})
add_subdirectory(core-tests)


# GObject Introspection

include(GObjectIntrospectionMacros)
add_target_gir_with_executable(scratchcore ${CMAKE_BINARY_DIR}/src/scratch-text-editor Scratch ${CMAKE_CURRENT_BINARY_DIR}/scratchcore.h ${CMAKE_BINARY_DIR}/src/scratch.h "${DEPS_CFLAGS}" 1.0 Gtk-3.0 Granite-1.0)
