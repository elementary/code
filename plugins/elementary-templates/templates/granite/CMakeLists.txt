
project ($$LOWER_CASE_NAME)
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/vala)
enable_testing ()

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

configure_file (${CMAKE_CURRENT_SOURCE_DIR}/src/config.vala.cmake ${CMAKE_CURRENT_SOURCE_DIR}/src/config.vala)
add_definitions(-DGETTEXT_PACKAGE="$$LOWER_CASE_NAME")

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED granite gtk+-3.0)
add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.14.0" MINIMUM)

file(GLOB_RECURSE sources src/*.vala)

include(ValaPrecompile)
vala_precompile(VALA_C
    src/$$NAME.vala
    src/config.vala
PACKAGES
    gtk+-3.0
    granite
OPTIONS
    --thread
    )

add_subdirectory (po)

add_executable($$LOWER_CASE_NAME ${VALA_C})

install (TARGETS $$LOWER_CASE_NAME RUNTIME DESTINATION bin)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/$$LOWER_CASE_NAME.desktop DESTINATION share/applications)
IF (EXISTS (${CMAKE_CURRENT_SOURCE_DIR}/data/$$LOWER_CASE_NAME.svg))
    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/$$LOWER_CASE_NAME.svg DESTINATION share/icons/hicolor/48x48/apps)
ENDIF ()


