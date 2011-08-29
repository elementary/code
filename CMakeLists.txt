# Check http://webdev.elementaryos.org/docs/developer-guide/cmake for documentation

cmake_minimum_required (VERSION 2.6)
cmake_policy (VERSION 2.6)

project (scratch)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/scratch")
set (GETTEXT_PACKAGE "scratch")
set (RELEASE_NAME "The Elementary Text Editor.")
set (VERSION "0.0.2")
set (VERSION_INFO "Release")
set (CMAKE_C_FLAGS "-ggdb")


list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)


# Configure file
configure_file (${CMAKE_SOURCE_DIR}/config.h.cmake ${CMAKE_BINARY_DIR}/config.h)
add_definitions(-include config.h)

# Scratch

set (SCRATCH_DEPS "gee-1.0;gobject-2.0;glib-2.0;gio-2.0;gconf-2.0;gtk+-3.0;granite;libsoup-2.4;pango")

find_package (PkgConfig)
pkg_check_modules (GLIB REQUIRED "glib-2.0 >= 2.26.0")
pkg_check_modules (GOBJECT REQUIRED "gobject-2.0 >= 2.26.0")
pkg_check_modules (GIO REQUIRED "gio-2.0 >= 2.26.0")
pkg_check_modules (GCONF REQUIRED "gconf-2.0 >= 2.31.91")
pkg_check_modules (GTK+ REQUIRED "gtk+-3.0 >= 3.0.8")
pkg_check_modules (LIBGRANITE REQUIRED "granite")
pkg_check_modules (LIBSOURCE REQUIRED "gtksourceview-3.0 >= 3.0")
pkg_check_modules (LIBSOUP REQUIRED "libsoup-2.4 >= 2.0")
pkg_check_modules (LIBPANGO REQUIRED "pango >= 1.0")
pkg_check_modules (DEPS REQUIRED ${SCRATCH_DEPS})

add_definitions (${DEPS_CFLAGS} ${LIBSOURCE_CFLAGS} ${GCONF_CFLAGS})
link_libraries (${DEPS_LIBRARIES} ${LIBSOURCE_LIBRARIES} ${GCONF_LIBRARIES})
link_directories (${DEPS_LIBRARY_DIRS} ${LIBSOURCE_LIBRARY_DIRS} ${GCONF_LIBRARY_DIRS})

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.12.0" MINIMUM)

include (ValaPrecompile)
vala_precompile (VALA_C
	src/main_window.vala
    src/scratch.vala
    src/settings.vala
    src/Widgets/menu.vala
    src/Widgets/share_menu.vala
    src/Widgets/notebook.vala
    src/Widgets/toolbar.vala
    src/Widgets/sourceview.vala
    src/Dialogs/preferences_dialog.vala
    src/Dialogs/save_dialog.vala
    src/Dialogs/save_on_close_dialog.vala
    src/Dialogs/pastebin_dialog.vala
    src/Services/document.vala
    src/Services/pastebin.vala
PACKAGES
	${SCRATCH_DEPS} scratchplugins
CUSTOM_VAPIS
    vapi/config.vapi
    vapi/gtksourceview-3.0.vapi
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}/libplugins
    --thread
)

# tranlation stuff
add_subdirectory(po)
# add_definitions (${CFLAGS} -Wall -Winit-self -Wwrite-strings -Wunreachable-code -Wstrict-prototypes )
add_executable (scratch ${VALA_C})
include_directories(${CMAKE_BINARY_DIR}/libplugins)
target_link_libraries (scratch scratchplugins)

#TODO: Installation
install (TARGETS scratch RUNTIME DESTINATION bin)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/scratch.desktop DESTINATION /usr/share/applications)

#
# GSettings Schema
#
SET (SCRATCH_SCHEMAS "org.elementary.scratch.gschema.xml")

# Have an option to not install the schema into where GLib is
option (GSETTINGS_LOCALINSTALL "Install GSettings Schemas locally instead of to the GLib prefix" ON)
if (GSETTINGS_LOCALINSTALL)
    SET (GSETTINGS_DIR "${CMAKE_INSTALL_PREFIX}/share/glib-2.0/schemas/")
else (GSETTINGS_LOCALINSTALL)
    execute_process (COMMAND ${PKG_CONFIG_EXECUTABLE} glib-2.0 --variable prefix OUTPUT_VARIABLE _glib_prefix OUTPUT_STRIP_TRAILING_WHITESPACE)
    SET (GSETTINGS_DIR "${_glib_prefix}/share/glib-2.0/schemas/")
endif (GSETTINGS_LOCALINSTALL)

# Run the validator and error if it fails
execute_process (COMMAND ${PKG_CONFIG_EXECUTABLE} gio-2.0 --variable glib_compile_schemas  OUTPUT_VARIABLE _glib_comple_schemas OUTPUT_STRIP_TRAILING_WHITESPACE)
execute_process (COMMAND ${_glib_comple_schemas} --dry-run --schema-file=${CMAKE_CURRENT_SOURCE_DIR}/${SCRATCH_SCHEMAS} ERROR_VARIABLE _schemas_invalid OUTPUT_STRIP_TRAILING_WHITESPACE)

if (_schemas_invalid)
  message (SEND_ERROR "Schema validation error: ${_schemas_invalid}")
endif (_schemas_invalid)

# Actually install and recomple schemas
message (STATUS "GSettings schemas will be installed into ${GSETTINGS_DIR}")
install (FILES ${SCRATCH_SCHEMAS} DESTINATION ${GSETTINGS_DIR} OPTIONAL)

option (GSETTINGS_COMPILE "Compile GSettings Schemas after installation" GSETTINGS_LOCALINSTALL)
if (GSETTINGS_COMPILE)
    install (CODE "message (STATUS \"Compiling GSettings schemas\")")
    install (CODE "execute_process (COMMAND ${_glib_comple_schemas} ${GSETTINGS_DIR})")
endif (GSETTINGS_COMPILE)

add_subdirectory(libplugins)
