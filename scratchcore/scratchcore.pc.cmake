prefix=@PREFIX@
exec_prefix=@DOLLAR@{prefix}
libdir=@DOLLAR@{prefix}/lib
includedir=@DOLLAR@{prefix}/include/

Name: @PKGNAME@
Description: @PKGNAME@ core
Version: 0.1
Libs: -L@DOLLAR@{libdir} -l@PKGNAME@
Cflags: -I@DOLLAR@{includedir}/${PKGNAME}
Requires: gtk+-3.0 gee-1.0 scratchplugins

