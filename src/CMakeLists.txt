install (FILES ${CMAKE_BINARY_DIR}/src/scratch.pc DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/pkgconfig/)
vala_precompile(VALA_C
    MainWindow.vala
    Scratch.vala
    Widgets/ShareMenu.vala
    Widgets/Notebook.vala
    Widgets/Tab.vala
    Widgets/TabLabel.vala
    Widgets/SplitView.vala
    Widgets/ToolBar.vala
    Dialogs/PreferencesDialog.vala
    Dialogs/SaveDialog.vala
    Dialogs/SaveOnCloseDialog.vala
    Dialogs/WarnDialog.vala
    Services/Document.vala
    Services/ZeitgeistLogger.vala
    Services/Encoding.vala
    config.vala
    Widgets/ComboSyntax.vala
    Widgets/StatusBar.vala
    Widgets/NotificationBar.vala
PACKAGES
    ${SCRATCH_DEPS}
    scratchcore
OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore
    --vapidir=${CMAKE_SOURCE_DIR}/vapi
    --thread
GENERATE_VAPI
    scratch
GENERATE_HEADER
    scratch
)
# tranlation stuff

add_executable (scratch-text-editor ${VALA_C})
add_dependencies(scratch-text-editor scratchcore)
target_link_libraries (scratch-text-editor scratchcore)

install (TARGETS scratch-text-editor RUNTIME DESTINATION bin)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/scratch.vapi DESTINATION share/vala/vapi/)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/scratch.deps DESTINATION share/vala/vapi/)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/scratch.h DESTINATION include/scratch/)