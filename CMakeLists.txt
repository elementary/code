# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)

project (scratch)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/scratch")
set (GETTEXT_PACKAGE "scratch")
set (RELEASE_NAME "This could kill your hamster!")
set (VERSION "0.0.1-alpha")
set (VERSION_INFO "Release")


list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)


# Configure file
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)

# Scratch

set (SCRATCH_DEPS "gobject-2.0;glib-2.0;gio-2.0;gtk+-3.0;granite;gtksourceview-3.0")

find_package (PkgConfig)
pkg_check_modules (GLIB REQUIRED "glib-2.0 >= 2.26.0")
pkg_check_modules (GOBJECT REQUIRED "gobject-2.0 >= 2.26.0")
pkg_check_modules (GIO REQUIRED "gio-2.0 >= 2.26.0")
pkg_check_modules (GTK+ REQUIRED "gtk+-3.0 >= 3.0.8")
pkg_check_modules (LIBGRANITE REQUIRED "granite")
pkg_check_modules (LIBSOURCE REQUIRED "gtksourceview-3.0 >= 3.0")
pkg_check_modules (DEPS REQUIRED ${SCRATCH_DEPS})

add_definitions (${DEPS_CFLAGS})
link_libraries (${DEPS_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS})

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.12.0" MINIMUM)

include (ValaPrecompile)
vala_precompile (VALA_C
	src/main_window.vala
    src/scratch.vala
    src/Widgets/menu.vala
    src/Widgets/notebook.vala
    src/Widgets/toolbar.vala
    src/Dialogs/preferences_dialog.vala
PACKAGES
	${SCRATCH_DEPS}
CUSTOM_VAPIS
    vapi/config.vapi
    #vapi/gtksourceview-3.0.vapi
OPTIONS
	--thread
)

# add_definitions (${CFLAGS} -Wall -Winit-self -Wwrite-strings -Wunreachable-code -Wstrict-prototypes )
add_executable (scratch ${VALA_C})

#TODO: Installation
install (TARGETS scratch RUNTIME DESTINATION bin)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/scratch.desktop DESTINATION /usr/share/applications)
