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

set(CFLAGS ${NORMAL_CFLAGS})
add_definitions(${CFLAGS})
set(LIBS
    ${NORMAL_LIBRARIES}
)
link_libraries(${LIBS})
set(LIB_PATHS
    ${NORMAL_LINK_DIRS}
)

link_directories(${LIB_PATHS})
#VALA stuff

vala_precompile(VALA_C
    PluginManager.vala
    PACKAGES
    gtk+-3.0
    gee-1.0
    gmodule-2.0
    libpeas-1.0
    peas-gtk
OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
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

set_target_properties (${PKGNAME} PROPERTIES
    VERSION ${SCRATCHPLUGINS_VERSION}
    SOVERSION ${SCRATCHPLUGINS_SOVERSION}
                       )
install (TARGETS ${PKGNAME} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
