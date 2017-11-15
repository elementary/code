include (Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    ../plugins
    DESKTOP_FILES
        ${CMAKE_BINARY_DIR}/data/org.pantheon.scratch.desktop.in
    APPDATA_FILES
        ${CMAKE_BINARY_DIR}/data/${CMAKE_PROJECT_NAME}.appdata.xml.in
        ${CMAKE_BINARY_DIR}/data/io.elementary.code.policy.xml.in
)
