# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)
project (scratch)
enable_testing ()
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/scratch")
set (GETTEXT_PACKAGE "scratch")
set (RELEASE_NAME "The Elementary Text Editor.")
set (VERSION "1.0")
set (VERSION_INFO "Release")
set (PLUGINDIR "${CMAKE_INSTALL_PREFIX}/lib/scratch/plugins/")
set (CMAKE_C_FLAGS "-ggdb")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
# Configure file

configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
configure_file (${CMAKE_SOURCE_DIR}/src/scratch.pc.cmake ${CMAKE_BINARY_DIR}/src/scratch.pc)
install (FILES ${CMAKE_BINARY_DIR}/src/scratch.pc DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/)
# Scratch

set (SCRATCH_DEPS "gtksourceview-3.0;gee-1.0;gobject-2.0;glib-2.0;gio-2.0;gconf-2.0;gtk+-3.0;granite;")
find_package (PkgConfig)
pkg_check_modules (GLIB REQUIRED "glib-2.0 >= 2.26.0")
pkg_check_modules (GOBJECT REQUIRED "gobject-2.0 >= 2.26.0")
pkg_check_modules (GIO REQUIRED "gio-2.0 >= 2.26.0")
pkg_check_modules (GTK+ REQUIRED "gtk+-3.0 >= 3.2")
pkg_check_modules (LIBGRANITE REQUIRED "granite")
pkg_check_modules (GCONF REQUIRED "gconf-2.0 >= 2.31.91")
pkg_check_modules (LIBSOURCE REQUIRED "gtksourceview-3.0 >= 3.0")
pkg_check_modules (DEPS REQUIRED ${SCRATCH_DEPS})
add_definitions (${DEPS_CFLAGS} ${LIBSOURCE_CFLAGS} ${GCONF_CFLAGS})
link_libraries (${DEPS_LIBRARIES} ${LIBSOURCE_LIBRARIES} ${GCONF_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS} ${LIBSOURCE_LIBRARY_DIRS} ${GCONF_LIBRARY_DIRS})
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.12.0" MINIMUM)
include (ValaPrecompile)
vala_precompile(VALA_C
    src/MainWindow.vala
    src/Scratch.vala
    src/Widgets/ShareMenu.vala
    src/Widgets/Notebook.vala
    src/Widgets/Tab.vala
    src/Widgets/TabLabel.vala
    src/Widgets/SplitView.vala
    src/Widgets/ToolBar.vala
    src/Dialogs/PreferencesDialog.vala
    src/Dialogs/SaveDialog.vala
    src/Dialogs/SaveOnCloseDialog.vala
    src/Dialogs/ToolBarEditor.vala
    src/Services/Document.vala
    src/config.vala
    src/Widgets/ComboSyntax.vala
    src/Widgets/StatusBar.vala
PACKAGES
    	${SCRATCH_DEPS}
    scratchplugins
    scratchcore
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}/libplugins
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore
    --thread
    GENERATE_VAPI
    scratch
    GENERATE_HEADER
    scratch
)
# tranlation stuff

add_subdirectory(po)
# add_definitions (${CFLAGS} -Wall -Winit-self -Wwrite-strings -Wunreachable-code -Wstrict-prototypes )

add_executable (scratch ${VALA_C})
include_directories(${CMAKE_BINARY_DIR}/libplugins)
include_directories(${CMAKE_BINARY_DIR}/scratchcore)
include_directories(${CMAKE_BINARY_DIR}/lib)
target_link_libraries (scratch scratchcore scratchplugins)
#TODO: Installation

install (TARGETS scratch RUNTIME DESTINATION bin)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/scratch.svg DESTINATION share/icons/hicolor/scalable/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/scratch.desktop DESTINATION share/applications)
install (FILES ${CMAKE_BINARY_DIR}/scratch.vapi DESTINATION share/vala/vapi/)
install (FILES ${CMAKE_BINARY_DIR}/scratch.h DESTINATION include/scratch/)
include(GSettings)
add_schema("org.elementary.scratch.gschema.xml")
add_subdirectory(libplugins)
add_subdirectory(scratchcore)
add_subdirectory(plugins)
