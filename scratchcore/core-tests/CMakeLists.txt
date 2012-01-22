# pkgconfig, real C code

set(CMAKE_INCLUDE_CURRENT_DIR ON)
find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED gtk+-3.0
 granite
 gee-1.0
 gtksourceview-3.0
 libpeas-1.0
 libpeas-gtk-1.0
)
set(CFLAGS ${DEPS_CFLAGS} ${DEPS_CFLAGS_OTHER} )
set(LIB_PATHS ${DEPS_LIBRARY_DIRS})
link_directories(${LIB_PATHS})
add_definitions(${CFLAGS})
vala_precompile(VALA_C
    main.vala
PACKAGES
    gtk+-3.0
    scratchcore
    scratchplugins
    granite
    gee-1.0
    gtksourceview-3.0
OPTIONS
    --thread
    --vapidir=${CMAKE_BINARY_DIR}/scratchcore
    --vapidir=${CMAKE_BINARY_DIR}/libplugins
)
add_executable(core-tests ${VALA_C})
target_link_libraries(core-tests ${DEPS_LIBRARIES})
target_link_libraries(core-tests scratchcore)
include_directories(${CMAKE_BINARY_DIR}/scratchcore)
include_directories(${CMAKE_BINARY_DIR}/libplugins)
include(Tests)
add_test_executable(core-tests)
