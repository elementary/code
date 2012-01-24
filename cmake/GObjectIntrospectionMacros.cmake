macro(add_target_gir TARGET_NAME GIR_NAME HEADER CFLAGS GRANITE_VERSION)
    set(PACKAGES "")
    foreach(PKG ${ARGN})
        set(PACKAGES ${PACKAGES} --include=${PKG})
    endforeach()
    install(CODE "set(ENV{LD_LIBRARY_PATH} \"${CMAKE_CURRENT_BINARY_DIR}:\$ENV{LD_LIBRARY_PATH}\")
    execute_process(COMMAND g-ir-scanner ${CFLAGS} -n ${GIR_NAME}
            --quiet
            --library ${PKGNAME} ${PACKAGES}
            -o ${CMAKE_CURRENT_BINARY_DIR}/${GIR_NAME}-${GRANITE_VERSION}.gir
            -L${CMAKE_CURRENT_BINARY_DIR}
            --nsversion=${GRANITE_VERSION} ${CMAKE_CURRENT_BINARY_DIR}/${HEADER})")
    install(CODE "execute_process(COMMAND g-ir-compiler ${CMAKE_CURRENT_BINARY_DIR}/${GIR_NAME}-${GRANITE_VERSION}.gir -o ${CMAKE_CURRENT_BINARY_DIR}/${GIR_NAME}-${GRANITE_VERSION}.typelib)")
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${GIR_NAME}-${GRANITE_VERSION}.gir DESTINATION share/gir-1.0/)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${GIR_NAME}-${GRANITE_VERSION}.typelib DESTINATION lib/girepository-1.0/)
endmacro()
