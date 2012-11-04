# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)
project (scratch)
enable_testing ()
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/scratch")
set (GETTEXT_PACKAGE "scratch")
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
set (RELEASE_NAME "The elementary Text Editor.")
set (VERSION "1.1.1")
set (VERSION_INFO "Release")
set (PLUGINDIR "${CMAKE_INSTALL_PREFIX}/lib/scratch/plugins/")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)


# Some configuration
configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)
configure_file (${CMAKE_SOURCE_DIR}/src/scratch.pc.cmake ${CMAKE_BINARY_DIR}/src/scratch.pc)



# Vala
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.15.1" MINIMUM)
include (ValaPrecompile)


# GSettings
include(GSettings)
add_schema("org.pantheon.scratch.gschema.xml")


# Dependencies
set (SCRATCH_DEPS libpeas-1.0 gtksourceview-3.0 gee-1.0 gobject-2.0 glib-2.0 gio-2.0 gconf-2.0 gtk+-3.0 granite zeitgeist-1.0 gobject-introspection-1.0)
find_package (PkgConfig)
pkg_check_modules (GTK+ REQUIRED "gtk+-3.0 >= 3.4")
pkg_check_modules (LIBSOURCE REQUIRED libpeas-gtk-1.0 gtksourceview-3.0>=3.0 gthread-2.0)
pkg_check_modules (DEPS REQUIRED ${SCRATCH_DEPS})
set(NORMAL_CFLAGS ${DEPS_CFLAGS} ${LIBSOURCE_CFLAGS} ${GCONF_CFLAGS})
set(NORMAL_LINK_DIRS ${DEPS_LIBRARY_DIRS} ${LIBSOURCE_LIBRARY_DIRS} ${GCONF_LIBRARY_DIRS})
set(NORMAL_LIBRARIES ${DEPS_LIBRARIES} ${LIBSOURCE_LIBRARIES} ${GCONF_LIBRARIES})

add_definitions (${DEPS_CFLAGS} ${LIBSOURCE_CFLAGS} ${GCONF_CFLAGS})
link_libraries (${DEPS_LIBRARIES} ${LIBSOURCE_LIBRARIES} ${GCONF_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS} ${LIBSOURCE_LIBRARY_DIRS} ${GCONF_LIBRARY_DIRS})


# Some include paths
include_directories(${CMAKE_BINARY_DIR}/scratchcore)
include_directories(${CMAKE_BINARY_DIR}/src)


# Subdirectories
add_subdirectory(src)
add_subdirectory(scratchcore)
add_subdirectory(plugins)
add_subdirectory(po)


# Data
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/scratch-text-editor.desktop DESTINATION share/applications)
