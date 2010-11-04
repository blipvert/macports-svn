# -*- coding: utf-8; mode: tcl; c-basic-offset: 4; indent-tabs-mode: nil; tab-width: 4; truncate-lines: t -*- vim:fenc=utf-8:et:sw=4:ts=4:sts=4
# $Id$

# Copyright (c) 2010 The MacPorts Project
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
# This portgroup defines standard settings when using Qt4.
#
# Usage:
# PortGroup     qt4 1.0

# check for +debug variant of this port, and make sure Qt was
# installed with +debug as well; if not, error out.
platform darwin {
    pre-extract {
        if {[variant_exists debug] && \
            [variant_isset debug] && \
           ![info exists building_qt4]} {
            if {![file exists ${prefix}/lib/libQtCore_debug.dylib]} {
                return -code error "\n\nERROR:\n\
In order to install this port as +debug,
Qt4 must also be installed with +debug.\n"
            }
        }
    }
}

# standard Qt4 name
global qt_name
set qt_name             qt4

# standard install directory
global qt_dir
set qt_dir              ${prefix}

# standard Qt documents directory
global qt_docs_dir
set qt_docs_dir         ${qt_dir}/share/doc/${qt_name}

# standard Qt plugins directory
global qt_plugins_dir
set qt_plugins_dir      ${qt_dir}/share/${qt_name}/plugins

# standard Qt mkspecs directory
global qt_mkspecs_dir
set qt_mkspecs_dir      ${qt_dir}/share/${qt_name}/mkspecs

# standard Qt imports directory
global qt_imports_dir
set qt_imports_dir      ${qt_dir}/share/${qt_name}/imports

# standard Qt includes directory
global qt_includes_dir
set qt_includes_dir     ${qt_dir}/include

# standard Qt libraries directory
global qt_libs_dir
set qt_libs_dir         ${qt_dir}/lib

# standard Qt non-.app executables directory
global qt_bins_dir
set qt_bins_dir         ${qt_dir}/bin

# standard Qt .app executables directory, if created
global qt_apps_dir
set qt_apps_dir         ${applications_dir}/Qt4

# standard Qt data directory
global qt_data_dir
set qt_data_dir         ${qt_dir}/share/${qt_name}

# standard Qt translations directory
global qt_translations_dir
set qt_translations_dir ${qt_dir}/share/${qt_name}/translations

# standard Qt sysconf directory
global qt_sysconf_dir
set qt_sysconf_dir      ${qt_dir}/etc/${qt_name}

# standard Qt examples directory
global qt_examples_dir
set qt_examples_dir     ${qt_dir}/share/${qt_name}/examples

# standard Qt demos directory
global qt_demos_dir
set qt_demos_dir        ${qt_dir}/share/${qt_name}/demos

# standard CMake module directory for Qt-related files
global qt_cmake_module_dir
set qt_cmake_module_dir ${qt_dir}/share/cmake/modules

# standard qmake command location
global qt_qmake_cmd
set qt_qmake_cmd        ${qt_dir}/bin/qmake

# standard moc command location
global qt_moc_cmd
set qt_moc_cmd          ${qt_dir}/bin/moc

# standard uic command location
global qt_uic_cmd
set qt_uic_cmd          ${qt_dir}/bin/uic

# standard lrelease command location
global qt_lrelease_cmd
set qt_lrelease_cmd     ${qt_dir}/bin/lrelease

# standard cmake info for Qt4
global qt_cmake_defines
set qt_cmake_defines    \
    "-DQT_QT_INCLUDE_DIR=${qt_includes_dir} \
     -DQT_LIBRARY_DIR=${qt_libs_dir} \
     -DQT_QMAKE_EXECUTABLE=${qt_qmake_cmd} \
     -DQT_ZLIB_LIBRARY=${prefix}/lib/libz.dylib \
     -DQT_PNG_LIBRARY=${prefix}/lib/libpng.dylib"

# set Qt understood arch types, based on user preference
options qt_arch_types
default qt_arch_types {[string map {i386 x86} [get_canonical_archs]]}

# allow for both qt4 and qt4 devel
if {![info exists building_qt4]} {
    depends_lib-append      path:bin/qmake:qt4-mac
}

# standard configure environment
configure.env-append    QTDIR=${qt_dir} \
                        QMAKE=${qt_qmake_cmd} \
                        MOC=${qt_moc_cmd}

if {${qt_dir} != ${prefix}} {
    configure.env-append PATH=${qt_dir}/bin:$env(PATH)
}

# standard build environment
build.env-append        QTDIR=${qt_dir} \
                        QMAKE=${qt_qmake_cmd} \
                        MOC=${qt_moc_cmd}

if {${qt_dir} != ${prefix}} {
    build.env-append    PATH=${qt_dir}/bin:$env(PATH)
}

# use PKGCONFIG for Qt discovery in configure scripts
depends_build-append    path:bin/pkg-config:pkgconfig

# use a parallel build by default
use_parallel_build      yes

# standard destroot environment
destroot.env-append     QTDIR=${qt_dir} \
                        QMAKE=${qt_qmake_cmd} \
                        MOC=${qt_moc_cmd} \
                        INSTALL_ROOT=${destroot} \
                        DESTDIR=${destroot}
if {${qt_dir} != ${prefix}} {
    destroot.env-append PATH=${qt_dir}/bin:$env(PATH)
}

# append Qt's PKGCONFIG path to whatever is there now.
set qt_pkg_config_path ${qt_dir}/lib/pkgconfig
if {${qt_dir} != ${prefix}} {
    set qt_pkg_config_path ${pkg_config_path}:${prefix}/lib/pkgconfig
}
if {${configure.pkg_config_path} == ""} {
    configure.pkg_config_path ${qt_pkg_config_path}
} else {
    configure.pkg_config_path ${qt_pkg_config_path}:${configure.pkg_config_path}
}
unset qt_pkg_config_path
