file(GLOB OUTLINE_ICONS "${CMAKE_SOURCE_DIR}/plugins/outline/icons/*.svg")
file(COPY ${OUTLINE_ICONS} DESTINATION ${CMAKE_BINARY_DIR}/plugins/outline/icons/)

configure_file(${CMAKE_SOURCE_DIR}/plugins/outline/icons/outline.gresource.xml.in ${CMAKE_BINARY_DIR}/plugins/outline/icons/outline.gresource.xml)
include (GResource)
glib_compile_resources (GLIB_RESOURCES_OUTLINE SOURCE outline.gresource.xml)
