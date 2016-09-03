# Compute VALA_SHORTVER
execute_process(
    COMMAND
      ${VALA_EXECUTABLE} "--version"
    OUTPUT_VARIABLE
      VALA_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
string(REPLACE "Vala " "" VALA_VERSION "${VALA_VERSION}")
string(REGEX REPLACE "^([0-9]+).*" "\\1" maj_ver "${VALA_VERSION}")
string(REGEX REPLACE "^[0-9]+\\.([0-9]+).*" "\\1" min_ver "${VALA_VERSION}")
math(EXPR is_odd "${min_ver} % 2")
if(${is_odd} EQUAL 1)
    math(EXPR min_ver "${min_ver} + 1")
endif()
set(VALA_SHORTVER "${maj_ver}.${min_ver}" CACHE INTERNAL "")

pkg_check_modules(OUTLINE_DEPS libvala-${VALA_SHORTVER})
if (${OUTLINE_DEPS_FOUND})

add_definitions(${NORMAL_CFLAGS})
link_directories(${NORMAL_LINK_DIRS})

set (PLUGIN_NAME "outline")

vala_precompile(VALA_C ${PLUGIN_NAME}
    CtagsSymbolResolver.vala
    OutlinePlugin.vala
    ValaProcessing/ComparisonHelper.vala
    ValaProcessing/SymbolItem.vala
    ValaProcessing/SymbolOutline.vala
    ValaProcessing/SymbolResolver.vala
    SymbolOutline.vala
PACKAGES
    gtk+-3.0
    gee-0.8
    granite
    scratchcore
    libpeas-1.0
    gtksourceview-3.0
    ${ZEITGEIST_DEPS}
    libvala-${VALA_SHORTVER}
OPTIONS
    ${DEFAULT_PLUGIN_OPTIONS}
)

include (GResource)
glib_compile_resources (GLIB_RESOURCES_OUTLINE SOURCE icons/outline.gresource.xml)
link_directories(${OUTLINE_DEPS_LIBRARY_DRIS})
add_definitions(${OUTLINE_DEPS_CFLAGS})

add_library(${PLUGIN_NAME} MODULE ${VALA_C} ${GLIB_RESOURCES_OUTLINE})
add_dependencies(${PLUGIN_NAME} ${LIBNAME})
target_link_libraries(${PLUGIN_NAME} ${NORMAL_LIBRARIES} ${OUTLINE_DEPS_LIBRARIES})

install(TARGETS ${PLUGIN_NAME} DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})
install(FILES ${PLUGIN_NAME}.plugin DESTINATION ${PLUGINDIR}/${PLUGIN_NAME})

message("-- Outline plugin will be compiled")
else()
message("-- Outline plugin will NOT be compiled")
endif()
