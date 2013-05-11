#!/bin/bash

#######
#use with: 
# $ ./project_creator.sh /path/to/destination "name_as_lower_case" "Comment on project" "generic name" \
#  "categories" "The Actual Name" "My Name, Not my name (authors...)" 1
# the last argument indicates wether the script generates a class derived from Granite.Application with some basic stuff
#######

FOLDER=$1
NAME=$2
COMMENT=$3
GENERICNAME=$4
CATEGORIES=$5
COMPLETENAME=$6
AUTHORS=$7
GENAPP=$8

cd ${FOLDER};
#mkdir ${NAME};
#cd ${NAME};

#create folders
mkdir src;
mkdir po;
mkdir data;

#get newest cmake elementary stuff
bzr branch lp:~xapantu/+junk/cmake-modules
mv cmake-modules/cmake ./
rm -r cmake-modules
#cp -R /home/tom/Programming/dropoff/cmake ./

#create the .desktop file
echo "[Desktop Entry]
Type=Application
Name=${NAME}
Comment=${COMMENT}
GenericName=${GENERICNAME}
Exec=${NAME} %U
Icon=${NAME}
Terminal=false
Categories=${CATEGORIES}
" > data/${NAME}.desktop

#the po stuff
echo "include (Translations)
add_translations_directory (${NAME})
add_translations_catalog (${NAME}
    ../src
)" > po/CMakeLists.txt

#the main cmake file
echo "
project (${NAME})
cmake_minimum_required (VERSION 2.8)
cmake_policy (VERSION 2.6)

list (APPEND CMAKE_MODULE_PATH \${CMAKE_SOURCE_DIR}/cmake/vala)
enable_testing ()

list (APPEND CMAKE_MODULE_PATH \${CMAKE_SOURCE_DIR}/cmake)

configure_file (\${CMAKE_SOURCE_DIR}/src/config.vala.cmake \${CMAKE_BINARY_DIR}/src/config.vala)
add_definitions(-DGETTEXT_PACKAGE=\"${NAME}\")

find_package(PkgConfig)
pkg_check_modules(DEPS REQUIRED granite gtk+-3.0)
add_definitions(\${DEPS_CFLAGS})
link_libraries(\${DEPS_LIBRARIES})
link_directories(\${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version(\"0.14.0\" MINIMUM)

file(GLOB_RECURSE sources src/*.vala)

include(ValaPrecompile)
vala_precompile(VALA_C
    \${sources}
    \${CMAKE_BINARY_DIR}/src/config.vala
PACKAGES
    gtk+-3.0
    granite
OPTIONS
    --thread
    )

add_subdirectory (po)

add_executable(${NAME} \${VALA_C})

install (TARGETS ${NAME} RUNTIME DESTINATION bin)
install (FILES \${CMAKE_CURRENT_SOURCE_DIR}/data/${NAME}.desktop DESTINATION share/applications)
IF (EXISTS (\${CMAKE_CURRENT_SOURCE_DIR}/data/${NAME}.svg))
    install (FILES \${CMAKE_CURRENT_SOURCE_DIR}/data/${NAME}.svg DESTINATION share/icons/hicolor/48x48/apps)
ENDIF ()

" > CMakeLists.txt

#the vala configuration file
echo "
namespace Constants {
    public const string DATADIR = \"@DATADIR@\";
    public const string PKGDATADIR = \"@PKGDATADIR@\";
    public const string GETTEXT_PACKAGE = \"@GETTEXT_PACKAGE@\";
    public const string RELEASE_NAME = \"@RELEASE_NAME@\";
    public const string VERSION = \"@VERSION@\";
    public const string VERSION_INFO = \"@VERSION_INFO@\";
    public const string PLUGINDIR = \"@PLUGINDIR@\";
}
" > src/config.vala.cmake

#default main file
if [ $GENAPP -eq 1 ]; then
year=`date +%Y`
echo "

namespace ${COMPLETENAME/ /} {
    
    public class ${COMPLETENAME/ /}App : Granite.Application {
        
        construct {
            program_name = \"${COMPLETENAME}\";
            exec_name = \"${COMPLETENAME}\";
            
            build_data_dir = Constants.DATADIR;
            build_pkg_data_dir = Constants.PKGDATADIR;
            build_release_name = Constants.RELEASE_NAME;
            build_version = Constants.VERSION;
            build_version_info = Constants.VERSION_INFO;
            
            app_years = \"${year}\";
            app_icon = \"${NAME}\";
            app_launcher = \"${NAME}.desktop\";
            application_id = \"net.launchpad.${NAME}\";
            
            main_url = \"https://code.launchpad.net/${NAME}\";
            bug_url = \"https://bugs.launchpad.net/${NAME}\";
            help_url = \"https://code.launchpad.net/${NAME}\";
            translate_url = \"https://translations.launchpad.net/${NAME}\";
            
            about_authors = {\"${AUTHORS}\"};
            about_documenters = {\"${AUTHORS}\"};
            about_artists = {\"${AUTHORS}\"};
            about_comments = \"${COMMENT}\";
            about_translators = \"\";
            about_license_type = Gtk.License.GPL_3_0;
        }
        
        public ${COMPLETENAME/ /}App () {
            
        }
        
        //the application started
        public override void activate () {
            
        }
        
        //the application was requested to open some files
        public override void open (File [] files, string hint) {
            
        }
    }
}

public static void main (string [] args) {
    Gtk.init (ref args);
    
    var app = new ${COMPLETENAME/ /}.${COMPLETENAME/ /}App ();
    
    app.run (args);
}
" > src/${NAME}.vala
else
echo "

public static void main (string [] args) {
    
}
" > src/${NAME}.vala
fi
