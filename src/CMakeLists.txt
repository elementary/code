vala_precompile(VALA_C
    MainWindow.vala
    Scratch.vala
    Utils.vala
    Dialogs/PreferencesDialog.vala
    Widgets/DocumentView.vala
    Widgets/ToolBar.vala
    Widgets/SearchManager.vala
    Widgets/SplitView.vala
    Widgets/SourceView.vala
    Services/Document.vala
    Services/Encoding.vala
    Services/FileHandler.vala
    Services/PluginManager.vala
    Services/Settings.vala
    #Services/TemplateManager.vala
    Services/ZeitgeistLogger.vala
    config.vala
PACKAGES
    ${SCRATCH_DEPS}
    posix
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --thread
GENERATE_VAPI
    ${LIBNAME}
GENERATE_HEADER
    ${LIBNAME}
)
# tranlation stuff

add_executable (scratch-text-editor ${VALA_C})

install (TARGETS scratch-text-editor RUNTIME DESTINATION bin)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/scratch-ui.xml DESTINATION share/scratch/)

#####
# Plugin Library
#####

# Bild library for plugins
add_library (${LIBNAME} SHARED
    ${VALA_C}
)

if(BUILD_STATIC MATCHES "Yes")
add_library (${LIBNAME}-static STATIC ${VALA_C})
set_target_properties (${PKGNAME}-static PROPERTIES OUTPUT_NAME ${LIBNAME})
install (TARGETS ${LIBNAME}-static DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/)
endif(BUILD_STATIC MATCHES "Yes")

set_target_properties (${LIBNAME} PROPERTIES
    VERSION ${LIBVERSION}
    SOVERSION ${SOVERSION}
)

add_dependencies(scratch-text-editor scratchcore)
target_link_libraries (scratch-text-editor scratchcore)

# Install lib stuffs
install (FILES ${CMAKE_BINARY_DIR}/src/scratchcore.pc DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/scratch.vapi DESTINATION share/vala/vapi/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/scratch.deps DESTINATION share/vala/vapi/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/scratch.h DESTINATION include/scratch/)
