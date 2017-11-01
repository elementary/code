vala_precompile(VALA_C ${EXEC_NAME}
    MainWindow.vala
    Application.vala
    Utils.vala
    DrawSpacesUtils.vala
    Dialogs/PreferencesDialog.vala
    Widgets/DocumentView.vala
    Widgets/FormatBar.vala
    Widgets/HeaderBar.vala
    Widgets/Pane.vala
    Widgets/PaneSwitcher.vala
    Widgets/SearchBar.vala
    Widgets/SplitView.vala
    Widgets/SourceView.vala
    Widgets/WelcomeView.vala
    Services/Document.vala
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
    ${GTKSOURCEVIEW_FLAGS}
    ${GRANITE_FLAGS}
GENERATE_VAPI
    ${LIBNAME}
GENERATE_HEADER
    ${LIBNAME}
)
# tranlation stuff

add_executable (${EXEC_NAME} ${VALA_C})

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_FULL_BINDIR})

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

install (TARGETS ${LIBNAME} DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR})

# Install lib stuffs
install (FILES ${CMAKE_BINARY_DIR}/src/${LIBNAME}.pc DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR}/pkgconfig/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${LIBNAME}.vapi DESTINATION ${CMAKE_INSTALL_FULL_DATAROOTDIR}/vala/vapi/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/${LIBNAME}.deps DESTINATION ${CMAKE_INSTALL_FULL_DATAROOTDIR}/vala/vapi/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/${LIBNAME}.h DESTINATION ${CMAKE_INSTALL_FULL_INCLUDEDIR}/scratch/)
