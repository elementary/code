prefix=@PREFIX@
exec_prefix=@DOLLAR@{prefix}
libdir=@DOLLAR@{prefix}/lib
includedir=@DOLLAR@{prefix}/include
 
Name: Scratch
Description: Scratch headers  
Version: 0.1  
Libs: -L@DOLLAR@{libdir} -l@LIBNAME@
Cflags: -I@DOLLAR@{includedir}/@CMAKE_PROJECT_NAME@
Requires: gtk+-3.0 gee-0.8 granite libsoup-2.4

