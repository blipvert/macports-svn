#!/usr/bin/env tclsh8.3
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
package require darwinports_dlist 1.0

namespace eval darwinports {
    namespace export bootstrap_options portinterp_options open_dports
    variable bootstrap_options "portdbpath libpath auto_path sources_conf prefix"
    variable portinterp_options "portdbpath portpath auto_path prefix portsharepath"
	
	variable open_dports {}
}

# Provided UI instantiations
# For standard messages, the following priorities are defined
#     debug, info, msg, warn, error
# Clients of the library are expected to provide ui_puts with the following prototype:
#     proc ui_puts {priority string nonl}
# ui_puts should handle the above defined priorities

proc ui_debug {str {nonl ""}} {
    ui_puts debug "$str" $nonl
}

proc ui_info {str {nonl ""}} {
    ui_puts info "$str" $nonl
}

proc ui_msg {str {nonl ""}} {
    ui_puts msg "$str" $nonl
}

proc ui_error {str {nonl ""}} {
    ui_puts error "$str" $nonl
}

proc ui_warn {str {nonl ""}} {
    ui_puts warn "$str" $nonl
}

proc dportinit {args} {
    global auto_path env darwinports::portdbpath darwinports::bootstrap_options darwinports::portinterp_options darwinports::portconf darwinports::sources darwinports::sources_conf darwinports::portsharepath

    if {[llength [array names env HOME]] > 0} {
	set HOME [lindex [array get env HOME] 1]
	if [file isfile [file join ${HOME} .portsrc]] {
	    set portconf [file join ${HOME} .portsrc]
	    lappend conf_files ${portconf}
	}
    }

    if {![info exists portconf] && [file isfile /etc/ports/ports.conf]} {
	set portconf /etc/ports/ports.conf
	lappend conf_files /etc/ports/ports.conf
    }
    if [info exists conf_files] {
	foreach file $conf_files {
	    set fd [open $file r]
	    while {[gets $fd line] >= 0} {
		foreach option $bootstrap_options {
		    if {[regexp "^$option\[ \t\]+(\[A-Za-z0-9\./\]+$)" $line match val] == 1} {
			set darwinports::$option $val
			global darwinports::$option
		    }
		}
	    }
        }
    }

    if {![info exists sources_conf]} {
        return -code error "sources_conf must be set in /etc/ports/ports.conf or in your .portsrc"
    }
    if {[catch {set fd [open $sources_conf r]} result]} {
        return -code error "$result"
    }
    while {[gets $fd line] >= 0} {
        if ![regexp {[\ \t]*#.*|^$} $line] {
            lappend sources $line
	}
    }
    if ![info exists sources] {
	if [file isdirectory dports] {
	    set sources "file://[pwd]/dports"
	} else {
	    return -code error "No sources defined in $sources_conf"
	}
    }

    if ![info exists portdbpath] {
	return -code error "portdbpath must be set in /etc/ports/ports.conf or in your ~/.portsrc"
    }
    if ![file isdirectory $portdbpath] {
	if ![file exists $portdbpath] {
	    if {[catch {file mkdir $portdbpath} result]} {
		return -code error "portdbpath $portdbpath does not exist and could not be created: $result"
	    }
	}
    }
    if ![file isdirectory $portdbpath] {
	return -code error "$portdbpath is not a directory. Please create the directory $portdbpath and try again"
    }

    set portsharepath ${prefix}/share/darwinports
    if ![file isdirectory $portsharepath] {
	return -code error "Data files directory '$portsharepath' must exist"
    }
    
    if ![info exists libpath] {
	set libpath "${prefix}/share/darwinports/Tcl"
    }

    if [file isdirectory $libpath] {
	lappend auto_path $libpath
	set darwinports::auto_path $auto_path
    } else {
	return -code error "Library directory '$libpath' must exist"
    }
}

proc darwinports::worker_init {workername portpath options variations} {
    global darwinports::portinterp_options auto_path

    # Create package require abstraction procedure
    $workername eval "proc PortSystem \{version\} \{ \n\
			package require port \$version \}"

    foreach proc {dportexec dportopen dportclose dportsearch} {
        $workername alias $proc $proc
    }

    # instantiate the UI functions
    foreach proc {ui_debug ui_info ui_warn ui_msg ui_error ui_gets ui_yesno ui_confirm ui_display} {
        $workername alias $proc $proc
    }

    foreach opt $portinterp_options {
	if ![info exists $opt] {
	    global darwinports::$opt
	}
        if [info exists $opt] {
            $workername eval set system_options($opt) \"[set $opt]\"
            $workername eval set $opt \"[set $opt]\"
        } #"
    }

    foreach {opt val} $options {
        $workername eval set user_options($opt) $val
        $workername eval set $opt $val
    }

    foreach {var val} $variations {
        $workername eval set variations($var) $val
    }
}

proc darwinports::fetch_port {url} {
    global darwinports::portdbpath tcl_platform
    set fetchdir [file join $portdbpath portdirs]
    set fetchfile [file tail $url]
    if {[catch {file mkdir $fetchdir} result]} {
        return -code error $result
    }
    if {![file writable $fetchdir]} {
    	return -code error "Port remote fetch failed: You do not have permission to write to $fetchdir"
    }
    if {${tcl_platform(os)} == "Darwin"} {
	if {[catch {exec curl -L -s -S -o [file join $fetchdir $fetchfile] $url} result]} {
	    return -code error "Port remote fetch failed: $result"
	}
    } else {
	if {[catch {exec fetch -q -o [file join $fetchdir $fetchfile] $url} result]} {
	    return -code error "Port remote fetch failed: $result"
	}
    }
    if {[catch {cd $fetchdir} result]} {
	return -code error $result
    }
    if {[catch {exec tar -zxf $fetchfile} result]} {
	return -code error "Port extract failed: $result"
    }
    if {[regexp {(.+).tgz} $fetchfile match portdir] != 1} {
        return -code error "Can't decipher portdir from $fetchfile"
    }
    return [file join $fetchdir $portdir]
}

proc darwinports::getprotocol {url} {
    if {[regexp {(?x)([^:]+)://.+} $url match protocol] == 1} {
        return ${protocol}
    } else {
        return -code error "Can't parse url $url"
    }
}

proc darwinports::getportdir {url} {
    if {[regexp {(?x)([^:]+)://(.+)} $url match protocol string] == 1} {
        switch -regexp -- ${protocol} {
            {^file$} { return $string}
	    {http|ftp} { return [darwinports::fetch_port $url] }
            default { return -code error "Unsupported protocol $protocol" }
        }
    } else {
        return -code error "Can't parse url $url"
    }
}

# dportopen
# Opens a DarwinPorts portfile specified by a URL.  The portfile is
# opened with the given list of options and variations.  The result
# of this function should be treated as an opaque handle to a
# DarwinPorts Portfile.

proc dportopen {porturl {options ""} {variations ""}} {
    global darwinports::portinterp_options darwinports::portdbpath darwinports::portconf darwinports::open_dports auto_path

	# Look for an already-open DPort with the same URL.
	# XXX: should compare options and variations here too.
	# if found, return the existing reference and bump the refcount.
	set dport [dlist_search $darwinports::open_dports porturl $porturl]
	if {$dport != {}} {
		set refcnt [ditem_key $dport refcnt]
		incr refcnt
		ditem_key $dport refcnt $refcnt
		return $dport
	}

	set portdir [darwinports::getportdir $porturl]
	cd $portdir
	set portpath [pwd]
	set workername [interp create]

	set dport [ditem_create]
	lappend darwinports::open_dports $dport
	ditem_key $dport porturl $porturl
	ditem_key $dport portpath $portpath
	ditem_key $dport workername $workername
	ditem_key $dport options $options
	ditem_key $dport variations $variations
	ditem_key $dport refcnt 1

    darwinports::worker_init $workername $portpath $options $variations
    if ![file isfile Portfile] {
        return -code error "Could not find Portfile in $portdir"
    }

    $workername eval source Portfile
	
	ditem_key $dport provides [$workername eval return \$portname]

    return $dport
}

proc _dporttest {dport} {
	# Check for the presense of the port in the registry
	set workername [ditem_key $dport workername]
	set res [$workername eval registry_exists \${portname} \${portversion}]
	if {$res != ""} {
		ui_debug "Found Dependency: receipt: $res"
		return 1
	} else {
		return 0
	}
}

proc _dportexec {target dport} {
	# xxx: set the work path?
	set workername [ditem_key $dport workername]
	if {![catch {$workername eval eval_targets $target} result] && $result == 0} {
		# xxx: clean after installing?
		#$workername eval eval_targets clean
		return 0
	} else {
		# An error occurred.
		return 1
	}
}

# dportexec
# Execute the specified target of the given dport.

proc dportexec {dport target} {
    global darwinports::portinterp_options

	set workername [ditem_key $dport workername]

	# XXX: move this into dportopen?
	if {[$workername eval eval_variants variations $target] != 0} {
		return 1
	}
	
	# Before we build the port, we must build its dependencies.
	# XXX: need a more general way of comparing against targets
	set dlist {}
	if {$target == "configure" || $target == "build" || $target == "install" ||
		$target == "package" || $target == "mpkg"} {

		if {[dportdepends $dport 1 1] != 0} {
			return 1
		}
		
		# Select out the dependents along the critical path,
		# but exclude this dport, we might not be installing it.
		set dlist [dlist_append_dependents $darwinports::open_dports $dport {}]
		
		dlist_delete dlist $dport

		# install them
		set dlist [dlist_eval $dlist _dporttest [list _dportexec "install"]]
		
		if {$dlist != {}} {
			ui_error "The following dependencies failed to build:"
			foreach ditem $dlist {
				ui_error "[ditem_key $ditem provides]" nonl
			}
			ui_error ""
			return 1
		}
	}
	
	# Build this port with the specified target
	return [$workername eval eval_targets $target]
	
	return 0
}

proc darwinports::getindex {source} {
    global darwinports::portdbpath
    # Special case file:// sources
    if {[darwinports::getprotocol $source] == "file"} {
        return [file join [darwinports::getportdir $source] PortIndex]
    }
    regsub {://} $source {.} source_dir
    regsub -all {/} $source_dir {_} source_dir
    return [file join $portdbpath sources $source_dir PortIndex]
}

proc dportsync {args} {
    global darwinports::sources darwinports::portdbpath tcl_platform

    foreach source $sources {
        # Special case file:// sources
        if {[darwinports::getprotocol $source] == "file"} {
            continue
        }
        set indexfile [darwinports::getindex $source]
	if {[catch {file mkdir [file dirname $indexfile]} result]} {
            return -code error $result
        }
	if {![file writable [file dirname $indexfile]]} {
	    return -code error "You do not have permission to write to [file dirname $indexfile]"
	}
	if {${tcl_platform(os)} == "Darwin"} {
	    exec curl -L -s -S -o $indexfile $source/PortIndex
	} else {
	    exec fetch -q -o $indexfile $source/PortIndex
	}
    }
}

proc dportsearch {regexp} {
    global darwinports::portdbpath darwinports::sources
    set matches [list]

    foreach source $sources {
        if {[catch {set fd [open [darwinports::getindex $source] r]} result]} {
            return -code error "Can't open index file for source $source. Have you synced your source indexes?"
        }
        while {[gets $fd line] >= 0} {
            set name [lindex $line 0]
            if {[regexp -- $regexp $name] == 1} {
                gets $fd line
                array set portinfo $line
                if [info exists portinfo(portarchive)] {
                    lappend line porturl ${source}/$portinfo(portarchive)
                } elseif [info exists portinfo(portdir)] {
                    lappend line porturl ${source}/$portinfo(portdir)
                }
                lappend matches $name
                lappend matches $line
		set match 1
            } else {
                set len [lindex $line 1]
                seek $fd $len current
            }
        }
        close $fd
	if {[info exists match] && $match == 1} {
	    break
	}
    }
    return $matches
}

proc dportinfo {dport} {
	set workername [ditem_key $dport workername]
    return [$workername eval array get PortInfo]
}

proc dportclose {dport} {
	global darwinports::open_dports
	set refcnt [ditem_key $dport refcnt]
	incr refcnt -1
	ditem_key $dport refcnt $refcnt
	if {$refcnt == 0} {
		dlist_delete darwinports::open_dports $dport
		set workername [ditem_key $dport workername]
		interp delete $workername
	}
}

##### Private Depspec API #####
# This API should be considered work in progress and subject to change without notice.
##### "

# dportdepends returns a list of dports which the given port depends on.
# - optionally includes the build dependencies in the list.
# - optionally recurses through the dependencies, looking for dependencies
#	of dependencies.

proc dportdepends {dport includeBuildDeps recurseDeps} {
	array set portinfo [dportinfo $dport]
	set depends {}
	if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
	if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }
	if {$includeBuildDeps != "" && [info exists portinfo(depends_build)]} {
		eval "lappend depends $portinfo(depends_build)"
	}

	foreach depspec $depends {
		# grab the portname portion of the depspec
		set portname [lindex [split $depspec :] 2]
		
		# Find the porturl
		if {[catch {set res [dportsearch "^$portname\$"]} error]} {
			ui_puts err "Internal error: port search failed: $error"
			return 1
		}
		foreach {name array} $res {
			array set portinfo $array
			if {[info exists portinfo(porturl)]} {
				set porturl $portinfo(porturl)
				break
			}
		}

		if {![info exists porturl]} {
			ui_error "Dependency '$portname' not found."
			return 1
		}

		set options [ditem_key $dport options]
		set variations [ditem_key $dport variations]
		
		set subport [dportopen $porturl $options $variations]

		# Append the sub-port's provides to the port's requirements list.
		ditem_append $dport requires "[ditem_key $subport provides]"

		if {$recurseDeps != ""} {
			set res [dportdepends $subport $includeBuildDeps $recurseDeps]
			if {$res != 0} {
				return $res
			}
		}
	}
	
	return 0
}
