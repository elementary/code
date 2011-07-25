#!/usr/bin/env python

VERSION = "0.1"
VERSION_MAJOR_MINOR =  ".".join(VERSION.split(".")[0:2])
APPNAME = "scratch"

srcdir = '.'
blddir = '_build_'

def set_options(opt):
    opt.tool_options('compiler_cc')
    opt.tool_options('gnu_dirs')

def configure(conf):
    conf.check_tool('compiler_cc vala gnu_dirs')

    conf.check_cfg(package='glib-2.0', uselib_store='GLIB',
            atleast_version='2.14.0', mandatory=True, args='--cflags --libs')
    conf.check_cfg(package='gobject-2.0', uselib_store='GOBJECT',
            atleast_version='2.14.0', mandatory=True, args='--cflags --libs')
    conf.check_cfg(package='gtk+-3.0', uselib_store='GTK+',
            atleast_version='3.0', mandatory=True, args='--cflags --libs')
    conf.check_cfg(package='granite', uselib_store='GRANITE',
            atleast_version='0.0.1', mandatory=True, args='--cflags --libs')
            
    conf.define('PACKAGE', APPNAME)
    conf.define('PACKAGE_NAME', APPNAME)
    conf.define('PACKAGE_STRING', APPNAME + '-' + VERSION)
    conf.define('PACKAGE_VERSION', APPNAME + '-' + VERSION)

    conf.define('VERSION', VERSION)
    conf.define('VERSION_MAJOR_MINOR', VERSION_MAJOR_MINOR)

def build(bld):
    bld.add_subdirs('src')
    bld.add_subdirs('vapi')

