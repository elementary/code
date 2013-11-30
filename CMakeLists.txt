# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.8)
project (scratch)
enable_testing ()
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share/scratch")
set (SCRIPTDIR "${CMAKE_INSTALL_PREFIX}/share/scratch/scripts")
set (PKGDATADIR "${DATADIR}/scratch")
set (GETTEXT_PACKAGE "scratch-text-editor")
set (RELEASE_NAME "The elementary Text Editor.")
set (VERSION "2.0.1")
set (VERSION_INFO "Release")
set (LIBNAME "scratchcore")
set (LIBVERSION "0")
set (SOVERSION 0)
set (PLUGINDIR "${CMAKE_INSTALL_PREFIX}/lib/scratch/plugins/")
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# Add 'make dist' command for creating release tarball
set (CPACK_PACKAGE_VERSION ${VERSION})
set (CPACK_SOURCE_GENERATOR "TGZ")
set (CPACK_SOURCE_PACKAGE_FILE_NAME "${CMAKE_PROJECT_NAME}-${CPACK_PACKAGE_VERSION}")
set (CPACK_SOURCE_IGNORE_FILES "/build/;/.bzr/;/.bzrignore;~$;${CPACK_SOURCE_IGNORE_FILES}")

include (CPack)
add_custom_target (dist COMMAND ${CMAKE_MAKE_PROGRAM} package_source)

# Some configuration
configure_file (${CMAKE_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_SOURCE_DIR}/src/config.vala)
configure_file (${CMAKE_SOURCE_DIR}/src/${LIBNAME}.pc.cmake ${CMAKE_BINARY_DIR}/src/${LIBNAME}.pc)

# Some definitions
add_definitions(-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")

# Vala
find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.22" MINIMUM)
include (ValaPrecompile)

add_definitions(-DVALA_VERSION="${VALA_SHORTVER}")
add_definitions(-w) # Disable gcc warnings

# Dependencies
set (SCRATCH_DEPS libpeas-1.0 libpeas-gtk-1.0 gtksourceview-3.0 gee-1.0 gobject-2.0 glib-2.0 gio-2.0 gtk+-3.0 granite zeitgeist-2.0)
find_package (PkgConfig)
pkg_check_modules (GTK+ REQUIRED "gtk+-3.0 >= 3.4")
pkg_check_modules (LIBSOURCE REQUIRED libpeas-gtk-1.0 gtksourceview-3.0>=3.0 gthread-2.0)
pkg_check_modules (DEPS REQUIRED ${SCRATCH_DEPS})

set (GTK310_FLAG "")
pkg_check_modules (GTK310 QUIET gtk+-3.0>=3.10)
if (HAS_GTK310)
    pkg_check_modules (GTK310 REQUIRED gtk+-3.0>=3.10)
    ensure_vala_version ("0.20" MINIMUM)
    set (GTK310_FLAGS "--define=HAS_GTK310")
endif (HAS_GTK310)

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
#add_subdirectory(scratchcore)
add_subdirectory (src)
add_subdirectory (scripts)
add_subdirectory (plugins)
add_subdirectory (schemas)
add_subdirectory (po)

# Data
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/scratch-text-editor.desktop DESTINATION share/applications)
