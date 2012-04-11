# $Id$
# 
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
# 3. Neither the name of The MacPorts Project nor the names of its
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
# This PortGroup automatically sets all the fields of the various cross binutils
# ports (e.g. spu-binutils).
# 
# Usage:
# 
#   PortGroup               crossbinutils 1.0
#   crossbinutils.setup     spu 2.20.51.0.5

options crossbinutils.target

proc crossbinutils.setup {target version} {
    global master_sites workpath worksrcpath extract.suffix

    crossbinutils.target ${target}

    name            ${target}-binutils
    version         ${version}
    categories      cross devel
    platforms       darwin
    license         GPL-3+
    maintainers     nomaintainer

    description     FSF Binutils for ${target} cross development
    long_description \
        Free Software Foundation development toolchain ("binutils") for \
        ${target} cross development.

    homepage        http://www.gnu.org/software/binutils/binutils.html
    master_sites    gnu:binutils \
                    http://mirrors.ibiblio.org/gnu/ftp/gnu/binutils/
    dist_subdir     binutils
    distname        binutils-${version}
    worksrcdir      binutils-[string trimright ${version} {[a-zA-Z]}]
    use_bzip2       yes

    post-extract {
        delete ${worksrcpath}/etc
        file mkdir ${workpath}/build
    }

    post-patch {
        set infopages {
            gas/doc         as
            bfd/doc         bfd
            binutils/doc    binutils
            gprof           gprof
            ld              ld
        }

        foreach {dir page} ${infopages} {
            # Fix texinfo source file
            set tex [glob -directory ${worksrcpath}/${dir} ${page}.texi*]
            reinplace \
                /setfilename/s/${page}/${crossbinutils.target}-${page}/ ${tex}
            reinplace s/(${page})/(${crossbinutils.target}-${page})/g ${tex}
            reinplace \
                "s/@file{${page}}/@file{${crossbinutils.target}-${page}}/g" \
                ${tex}
            move ${tex} \
                ${worksrcpath}/${dir}/${crossbinutils.target}-${page}[file extension ${tex}]

            # Fix Makefile
            reinplace -E \
                s/\[\[:<:\]\]${page}\\.(info|texi)/${crossbinutils.target}-&/g \
                ${worksrcpath}/${dir}/Makefile.in
        }

        # Fix packages' names.
        foreach dir {bfd binutils gas gold gprof ld opcodes} {
            reinplace "/^ PACKAGE=/s/=.*/=${crossbinutils.target}-${dir}/" \
                ${worksrcpath}/${dir}/configure
        }

        # Do not install libiberty
        reinplace {/^install:/s/ .*//} ${worksrcpath}/libiberty/Makefile.in
    }

    depends_lib \
        port:gettext

    configure.dir   ${workpath}/build
    configure.cmd   ${worksrcpath}/configure

    configure.ldflags-append \
        -lintl

    configure.args \
        --target=${target} \
        --program-prefix=${target}-

    build.dir ${workpath}/build

    destroot.violate_mtree yes

    post-destroot {
        set docdir ${prefix}/share/doc/${name}
        xinstall -d ${destroot}${docdir}
        eval xinstall -m 644 \
            [glob -type f ${worksrcpath}/{COPYING*,ChangeLog,MAINTAINERS,README*}] \
            ${destroot}${docdir}
    }

    universal_variant no

    livecheck.type  regex
    livecheck.url   [lindex ${master_sites} 1]
    livecheck.regex "binutils-((?!.*binutils.*|\\${extract.suffix}).*)\\${extract.suffix}"
}
