# et:ts=4
# python26-1.0.tcl
#
# $Id$
#
# Copyright (c) 2008 The MacPorts Project,
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

# Can be removed once MacPorts 1.7.0 is released
if {![info exists frameworks_dir]} {
    set frameworks_dir ${prefix}/Library/Frameworks
}
set prefix ${frameworks_dir}/Python.framework/Versions/2.6

set python.bin	${prefix}/bin/python2.6
set python.lib	${prefix}/Python
set python.libdir ${prefix}/lib/python2.6
set python.pkgd	${prefix}/lib/python2.6/site-packages
set python.include	${prefix}/include/python2.6

categories		python

dist_subdir		python

depends_lib		port:python26

use_configure	no

build.cmd		${python.bin} setup.py --no-user-cfg
build.target	build

destroot.cmd	${python.bin} setup.py --no-user-cfg
destroot.destdir	--prefix=${prefix} --root=${destroot}

pre-destroot	{
	xinstall -d -m 755 ${destroot}${prefix}/share/doc/${name}/examples
}
