include (Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    ../plugins
    DESKTOP_FILES
<<<<<<< 8b5b2465b493be8b2266d3b9095d890dfe96ba01
        ${CMAKE_BINARY_DIR}/data/org.pantheon.scratch.desktop.in
=======
        ${CMAKE_SOURCE_DIR}/data/${CMAKE_PROJECT_NAME}.desktop.in
>>>>>>> Begin rename to Code
    APPDATA_FILES
        ${CMAKE_BINARY_DIR}/data/${CMAKE_PROJECT_NAME}.appdata.xml.in
)
