vala_precompile(VALA_C
    MainWindow.vala
    Scratch.vala
    Utils.vala
    Dialogs/PreferencesDialog.vala
    Widgets/DocumentView.vala
    Widgets/ToolBar.vala
    Widgets/LoadingView.vala
    Widgets/SearchManager.vala
    Widgets/SplitView.vala
    Widgets/SourceView.vala
    Services/Document.vala
    Services/Encoding.vala
    Services/FileHandler.vala
    Services/PluginManager.vala
    Services/Settings.vala
    Services/TemplateManager.vala
    Services/ZeitgeistLogger.vala
    config.vala
PACKAGES
    ${SCRATCH_DEPS}
    posix
OPTIONS
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --thread
    ${ZEITGEIST_OPTIONS}
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
set (LIBS ${DEPS_LIBRARIES} -lm)
set (LIB_PATHS ${DEPS_LIBRARY_DIRS})
link_directories (${LIB_PATHS})

set (LIB_FILES ${C_SOURCES} ${VALA_C})

add_library (${LIBNAME} SHARED
    ${LIB_FILES}
)

target_link_libraries (${LIBNAME} ${LIBS})

set_target_properties (${LIBNAME} PROPERTIES
    VERSION ${LIBVERSION}.0
    SOVERSION ${SOVERSION})

install (TARGETS ${LIBNAME} DESTINATION ${CMAKE_INSTALL_PREFIX}/lib)

# Install lib stuffs
install (FILES ${CMAKE_BINARY_DIR}/src/${LIBNAME}.pc DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${LIBNAME}.vapi DESTINATION share/vala/vapi/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/${LIBNAME}.deps DESTINATION share/vala/vapi/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${LIBNAME}.h DESTINATION include/scratch/)
