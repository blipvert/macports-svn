#!/usr/bin/tclsh
# darwinports.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
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
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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
package provide darwinports 1.0

global ports_opts
global bootstrap_options
set bootstrap_options "sysportpath libpath auto_path"
set portinterp_options "sysportpath portpath auto_path portconf"
set uniqid 0

proc dportinit {args} {
    global auto_path env bootstrap_options sysportpath portconf

    if [file isfile /etc/ports.conf] {
	set portconf /etc/ports.conf
	set fd [open /etc/ports.conf r]
	while {[gets $fd line] >= 0} {
	    foreach option $bootstrap_options {
		if {[regexp "^$option\[ \t\]+(\[A-Za-z0-9/\]+$)" $line match val] == 1} {
		    set $option $val
		}
	    }
	}
    }

    # Prefer the PORTPATH environment variable
    if {[llength [array names env PORTPATH]] > 0} {
	set sysportpath [lindex [array get env PORTPATH] 1]
    }

    if ![info exists sysportpath] {
	return -code error "sysportpath must be set in /etc/ports.conf or in the PORTPATH env variable"
    }
    if ![file isdirectory $sysportpath] {
	return -code error "/etc/ports.conf or PORTPATH env variable must refer to a valid directory"
    }
	
    if ![info exists libpath] {
	set libpath /usr/local/share/darwinports/Tcl
    }

    if [file isdirectory $libpath] {
	lappend auto_path $libpath
    } else {
	return -code error "Library directory '$libpath' must exist"
    }
}

proc dportopen {portdir {options ""}} {
    global portpath portinterp_options uniqid

    if [file isdirectory $portdir] {
	cd $portdir
	set portpath [pwd]
	set workername workername[incr uniqid]
	interp create $workername
	$workername alias dportbuild dportbuild

	foreach opt $portinterp_options {
		upvar #0 $opt upopt
		if [info exists upopt] {
			$workername eval set system_options($opt) \"$upopt\"
			$workername eval set $opt \"$upopt\"
		}
	}

	foreach opt $options {
		if {[regexp {([A-Za-z0-9_\.]+)=(.+)} $opt match key val] == 1} {
			$workername eval set user_options($key) \"$val\"
			$workername eval set $key \"$val\"
		}
	}
	$workername eval source Portfile
	$workername eval {flock [open Portfile r] -exclusive}
    } else {
	return -code error "Portdir $portdir does not exist"
    }
    return $workername
}

proc dportbuild {workername target} {
    global targets portpath portinterp_options uniqid

    return [$workername eval eval_targets targets $target]
}

proc dportclose {workername} {
    interp delete $workername
}
