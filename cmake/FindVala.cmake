#
# cmake/vala/FindVala.cmake
#
##
# Find module for the Vala compiler (valac)
#
# This module determines whether a Vala compiler is installed on the current
# system and where its executable is.
#
# Call the module using "find_package(Vala) from within your CMakeLists.txt.
#
# The following variables will be set after an invocation:
#
#  VALA_FOUND       Whether the vala compiler has been found or not
#  VALA_EXECUTABLE  Full path to the valac executable if it has been found
#  VALA_VERSION     Version number of the available valac
#
#  VALA_SHORTVER    Short version of valac (major.minor). Round up development
#                   versions. E.g. 0.19.1 -> 0.20, 0.20.1 -> 0.20
#  VALA_LIBPKG      Name of libvala library (libvala-${VALA_SHORTVER}).
#  VALA_VAPIDIR     Vapi directory path.
#  VALA_DATADIR     Path to libvala data directory. E.g. /usr/share/libvala-0.20
#  VALA_VAPIGEN     Path to vapigen executable.
#  VALA_GEN_INTROSPECT  Path to version specific gen-introspect executable.
#  VALA_VALA_GEN_INTROSPECT  Path to version independent gen-introspect
#                   executable.
#
##

# Copyright (C) 2013, Valama development team
#
# Valama is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Valama is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.
#
##
# Copyright 2009-2010 Jakob Westhoff. All rights reserved.
# Copyright 2010-2011 Daniel Pfeifer
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY JAKOB WESTHOFF ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL JAKOB WESTHOFF OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are those
# of the authors and should not be interpreted as representing official policies,
# either expressed or implied, of Jakob Westhoff
##

# Search for the valac executable in the usual system paths.
find_program(VALA_EXECUTABLE "valac")
mark_as_advanced(VALA_EXECUTABLE)

# Determine the valac version
if(VALA_EXECUTABLE)
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
    math(EXPR short_ver "${min_ver} + 1")
  endif()
  set(VALA_SHORTVER "${maj_ver}.${min_ver}" CACHE INTERNAL "")
  if(NOT "${maj_ver}" STREQUAL "" AND NOT "${min_ver}" STREQUAL "")
    set(VALA_LIBPKG "libvala-${VALA_SHORTVER}" CACHE INTERNAL "")

    find_package(PkgConfig)
    pkg_check_modules("VALA" REQUIRED "${VALA_LIBPKG}")
    _pkgconfig_invoke("${VALA_LIBPKG}" "VALA" VAPIDIR "" "--variable=vapidir")
    _pkgconfig_invoke("${VALA_LIBPKG}" "VALA" DATADIR "" "--variable=datadir")
    set(VALA_DATADIR "${VALA_DATADIR}/vala" CACHE INTERNAL "")
    _pkgconfig_invoke("${VALA_LIBPKG}" "VALA" VAPIGEN "" "--variable=vapigen")
    _pkgconfig_invoke("${VALA_LIBPKG}" "VALA" GEN_INTROSPECT "" "--variable=gen_introspect")
    _pkgconfig_invoke("${VALA_LIBPKG}" "VALA" VALA_GEN_INTROSPECT "" "--variable=vala_gen_introspect")
  endif()
endif()

# Handle the QUIETLY and REQUIRED arguments, which may be given to the find call.
# Furthermore set VALA_FOUND to TRUE if Vala has been found (aka.
# VALA_EXECUTABLE is set)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Vala
  REQUIRED_VARS
    VALA_EXECUTABLE
    VALA_SHORTVER
    VALA_LIBPKG
    VALA_VAPIDIR
    VALA_DATADIR
    VALA_VAPIGEN
    VALA_GEN_INTROSPECT
    VALA_VALA_GEN_INTROSPECT
  VERSION_VAR
    VALA_VERSION
)