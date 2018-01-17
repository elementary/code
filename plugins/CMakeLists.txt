set (DEFAULT_PLUGIN_OPTIONS
    --thread
    --vapidir=${CMAKE_SOURCE_DIR}/vapi/
    --vapidir=${CMAKE_BINARY_DIR}/src/
    --target-glib=2.32
)

add_subdirectory (contractor)
add_subdirectory (pastebin)
add_subdirectory (folder-manager)
add_subdirectory (terminal)
add_subdirectory (browser-preview)
add_subdirectory (strip-trailing-save)
add_subdirectory (spell)
add_subdirectory (open-with)
add_subdirectory (brackets-completion)
add_subdirectory (word-completion)
add_subdirectory (outline)
add_subdirectory (vim-emulation)
add_subdirectory (highlight-word-selection)
add_subdirectory (detect-indent)
add_subdirectory (preserve-indent)
add_subdirectory (toggle-code-comments)
