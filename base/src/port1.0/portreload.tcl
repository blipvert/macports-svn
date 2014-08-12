# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# $Id$
#
# Copyright (c) 2007-2014 The MacPorts Project
# Copyright (c) 2007 James D. Berry
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of The MacPorts Project nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide portreload 1.0
package require portutil 1.0

set org.macports.reload [target_new org.macports.reload portreload::reload_main]
target_runtype ${org.macports.reload} always
target_state ${org.macports.reload} no
target_provides ${org.macports.reload} reload
target_requires ${org.macports.reload} main

namespace eval portreload {
}

options reload.asroot
default reload.asroot yes

set_ui_prefix

proc portreload::reload_main {args} {
    global startupitem.type startupitem.name startupitem.location startupitem.plist
    set launchctl_path ${portutil::autoconf::launchctl_path}

    foreach { path } "/Library/${startupitem.location}/${startupitem.plist}" {
        if {$launchctl_path eq ""} {
            return -code error [format [msgcat::mc "launchctl command was not found by configure"]]
        } elseif {![file exists $path]} {
            return -code error [format [msgcat::mc "Launchd plist %s was not found"] $path]
        } else {
            # Basically run port unload; port load.
            exec -ignorestderr $launchctl_path unload -w $path
            exec -ignorestderr $launchctl_path load -w $path
        }
    }

    return
}
