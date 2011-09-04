set (PKGNAME scratchplugins)
set (PKGNAME_ SCRATCHPLUGINS)
set (${PKGNAME_}_VERSION 0.1)
# increase when you broke the API

set (${PKGNAME_}_SOVERSION 0)
set (PREFIX ${CMAKE_INSTALL_PREFIX})
set (DOLLAR "$")
# You hear that? It's kittens being killed by the gods of cmake

configure_file (${CMAKE_CURRENT_SOURCE_DIR}/${PKGNAME}.pc.cmake ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.pc DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/)
# Check for the deps

find_package(PkgConfig)
set(PKG_DEPS gtk+-3.0 gee-1.0)
pkg_check_modules(DEPSPLUGS REQUIRED ${PKG_DEPS})
# Link all

set(CFLAGS ${DEPSPLUGS_CFLAGS} ${DEPSPLUGS_CFLAGS_OTHER})
add_definitions(${CFLAGS} "-DGETTEXT_PACKAGE=\"${PKGNAME_}\"")
set(LIBS
	${DEP_LIBRARIES}
)
link_libraries(${LIBS})
set(LIB_PATHS
	${DEPS_LIBRARY_DIRS}
)
link_directories(${LIB_PATHS})
#VALA stuff

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.12.0" MINIMUM)
include(ValaPrecompile)
vala_precompile(VALA_C
PluginManager.vala
module.vapi
PACKAGES
gtk+-3.0
gee-1.0
OPTIONS
--thread
GENERATE_VAPI
${PKGNAME}
GENERATE_HEADER
${PKGNAME}
)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.vapi DESTINATION ${CMAKE_INSTALL_PREFIX}/share/vala/vapi/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/${PKGNAME}.deps DESTINATION ${CMAKE_INSTALL_PREFIX}/share/vala/vapi/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${PKGNAME}.h DESTINATION ${CMAKE_INSTALL_PREFIX}/include/${PKGNAME}/)
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
    VERSION ${SCRATCHPLUGINS_VERSION}
    SOVERSION ${SCRATCHPLUGINS_SOVERSION}
                       )
install (TARGETS ${PKGNAME} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
