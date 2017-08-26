include (Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    ../plugins
    DESKTOP_FILES
        ${CMAKE_SOURCE_DIR}/data/org.pantheon.scratch.desktop.in
    APPDATA_FILES
        ${CMAKE_SOURCE_DIR}/data/io.elementary.code.appdata.xml.in
)
