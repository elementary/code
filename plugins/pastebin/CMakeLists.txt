# Check http://elementaryos.org/docs/developer-guide/cmake for documentation

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED
	gtk+-3.0
    libsoup-2.4
    granite
    ${SCRATCH_DEPS}
)
set(CFLAGS
	${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER}
)
include_directories(${CMAKE_SOURCE_DIR}/lib/)
include_directories(${CMAKE_SOURCE_DIR})
include_directories(${CMAKE_SOURCE_DIR}/libplugind/)
# Vala

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.12.0" MINIMUM)
include(ValaPrecompile)
vala_precompile(VALA_C
    pastebin.vala
    pastebin_dialog.vala
PACKAGES
    gtk+-3.0
    scratchplugins
    libsoup-2.4
    granite
    scratch
    ${SCRATCH_DEPS}
CUSTOM_VAPIS
    ${CMAKE_SOURCE_DIR}/vapi/gtksourceview-3.0.vapi
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}/libplugins/
    --vapidir=${CMAKE_BINARY_DIR}
)
add_definitions(${CFLAGS})
link_directories(${LIB_PATHS})
add_library(scratchpastebin SHARED 
    ${VALA_C})
target_link_libraries(scratchpastebin scratchplugins) # useless, it is just for the build depends
install(TARGETS scratchpastebin DESTINATION share/scratch/plugins/core/)
install(FILES pastebin.plug DESTINATION share/scratch/plugins/core/)

include_directories(${CMAKE_BINARY_DIR}/scratchplugins/)

add_dependencies(scratchpastebin scratch)
