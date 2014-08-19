# et:ts=4
# porttrace.tcl
#
# $Id$
#
# Copyright (c) 2005-2006 Paul Guyot <pguyot@kallisys.net>,
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

package provide porttrace 1.0
package require Pextlib 1.0
package require portutil 1.0

namespace eval porttrace {
    proc appendEntry {sandbox path action} {
        upvar 2 $sandbox sndbxlst

        set mapping {}
        # Escape backslashes with backslashes
        lappend mapping "\\" "\\\\"
        # Escape colons with \:
        lappend mapping ":" "\\:"
        # Escape equal signs with \=
        lappend mapping "=" "\\="

        set normalizedPath [file normalize $path]
        lappend sndbxlst "[string map $mapping $path]=$action"
        if {$normalizedPath ne $path} {
            lappend sndbxlst "[string map $mapping $normalizedPath]=$action"
        }
    }

    ##
    # Append a trace sandbox entry suitable for allowing access to
    # a directory to a given sandbox list.
    #
    # @param sandbox The name of the sandbox list variable
    # @param path The path that should be permitted
    proc allow {sandbox path} {
        appendEntry $sandbox $path "+"
    }

    ##
    # Append a trace sandbox entry suitable for denying access to a directory
    # (and stopping processing of the sandbox) to a given sandbox list.
    #
    # @param sandbox The name of the sandbox list variable
    # @param path The path that should be denied
    proc deny {sandbox path} {
        appendEntry $sandbox $path "-"
    }

    ##
    # Append a trace sandbox entry suitable for deferring the access decision
    # back to MacPorts to query for dependencies to a given sandbox list.
    #
    # @param sandbox The name of the sandbox list variable
    # @param path The path that should be handed back to MacPorts for further
    #             processing.
    proc ask {sandbox path} {
        appendEntry $sandbox $path "?"
    }
}

proc porttrace::trace_start {workpath} {
    global prefix os.platform developer_dir macportsuser
    if {${os.platform} == "darwin"} {
        if {[catch {package require Thread} error]} {
            ui_warn "trace requires Tcl Thread package ($error)"
        } else {
            global env trace_fifo trace_sandboxbounds portpath distpath altprefix
            # Create a fifo.
            # path in unix socket limited to 109 chars
            # # set trace_fifo "$workpath/trace_fifo"
            set trace_fifo "/tmp/macports_trace_[pid]-[expr {int(rand()*1000)}]"
            file delete -force $trace_fifo

            # Create the thread/process.
            create_slave $workpath $trace_fifo

            # Launch darwintrace.dylib.

            set tracelib_path [file join ${portutil::autoconf::tcl_package_path} darwintrace1.0 darwintrace.dylib]

            if {[info exists env(DYLD_INSERT_LIBRARIES)] && [string length "$env(DYLD_INSERT_LIBRARIES)"] > 0} {
                set env(DYLD_INSERT_LIBRARIES) "${env(DYLD_INSERT_LIBRARIES)}:${tracelib_path}"
            } else {
                set env(DYLD_INSERT_LIBRARIES) ${tracelib_path}
            }
            set env(DARWINTRACE_LOG) "$trace_fifo"

            # The sandbox is limited to:
            set trace_sandbox [list]

            # Allow work-, port-, and distpath
            allow trace_sandbox $workpath
            allow trace_sandbox $portpath
            allow trace_sandbox $distpath

            # Allow standard system directories
            allow trace_sandbox "/bin"
            allow trace_sandbox "/sbin"
            allow trace_sandbox "/dev"
            allow trace_sandbox "/usr/bin"
            allow trace_sandbox "/usr/sbin"
            allow trace_sandbox "/usr/include"
            allow trace_sandbox "/usr/lib"
            allow trace_sandbox "/usr/libexec"
            allow trace_sandbox "/usr/share"
            allow trace_sandbox "/System/Library"
            # Deny /Library/Frameworks, third parties install there
            deny  trace_sandbox "/Library/Frameworks"
            # But allow the rest of /Library
            allow trace_sandbox "/Library"

            # Allow a few configuration files
            allow trace_sandbox "/etc/passwd"
            allow trace_sandbox "/etc/groups"
            allow trace_sandbox "/etc/localtime"

            # Allow temporary locations
            allow trace_sandbox "/tmp"
            allow trace_sandbox "/var/tmp"
            allow trace_sandbox "/var/folders"
            allow trace_sandbox "/var/empty"
            allow trace_sandbox "/var/run"
            if {[info exists env(TMPDIR)]} {
                set tmpdir [string trim $env(TMPDIR)]
                if {$tmpdir ne ""} {
                    allow trace_sandbox $tmpdir
                }
            }

            # Allow access to some Xcode specifics
            allow trace_sandbox "/var/db/xcode_select_link"
            allow trace_sandbox "/var/db/mds"
            allow trace_sandbox [file normalize ~${macportsuser}/Library/Preferences/com.apple.dt.Xcode.plist]
            allow trace_sandbox "$env(HOME)/Library/Preferences/com.apple.dt.Xcode.plist"

            # Allow access to developer_dir; however, if it ends with /Contents/Developer, strip
            # that. If it doesn't leave that in place to avoid allowing access to "/"!
            set ddsplit [file split [file normalize [file join ${developer_dir} ".." ".."]]]
            if {[llength $ddsplit] > 2 && [lindex $ddsplit end-1] eq "Contents" && [lindex $ddsplit end] eq "Developer"} {
                set ddsplit [lrange $ddsplit 0 end-2]
            }
            allow trace_sandbox [file join {*}$ddsplit]

            # Allow launchd.db access to avoid failing on port-load(1)/port-unload(1)/port-reload(1)
            allow trace_sandbox "/var/db/launchd.db"

            # Deal with ccache
            allow trace_sandbox "$env(HOME)/.ccache"
            if {[info exists env(CCACHE_DIR)]} {
                set ccachedir [string trim $env(CCACHE_DIR)]
                if {$ccachedir ne ""} {
                    allow trace_sandbox $ccachedir
                }
            }

            # Defer back to MacPorts for dependency checks inside $prefix. This must be at the end,
            # or it'll be used instead of more specific rules.
            ask trace_sandbox $prefix

            ui_debug "Tracelib Sandbox is:"
            foreach sandbox $trace_sandbox {
                ui_debug "\t$sandbox"
            }
            set trace_sandboxbounds [join $trace_sandbox :]
            tracelib setsandbox $trace_sandboxbounds
        }
    }
}

# Enable the fence.
# Only done for targets that should only happen in the sandbox.
proc porttrace::trace_enable_fence {} {
    tracelib enablefence
}

# Check the list of ports.
# Output a warning for every port the trace revealed a dependency on
# that isn't included in portslist
# This method must be called after trace_start
proc porttrace::trace_check_deps {target portslist} {
    # Get the list of ports.
    set ports [slave_send porttrace::slave_get_ports]

    # Compare with portslist
    set portslist [lsort $portslist]
    foreach port $ports {
        if {[lsearch -sorted -exact $portslist $port] == -1} {
            ui_warn "Target $target has an undeclared dependency on $port"
        }
    }
    foreach port $portslist {
        if {[lsearch -sorted -exact $ports $port] == -1} {
            ui_debug "Target $target has no traceable dependency on $port"
        }
    }
}

# Check that no violation happened.
# Output a warning for every sandbox violation the trace revealed.
# This method must be called after trace_start
proc porttrace::trace_check_violations {} {
    # Get the list of violations.
    set violations [slave_send porttrace::slave_get_sandbox_violations]

    foreach violation [lsort -unique $violations] {
        ui_warn "An activity was attempted outside sandbox: $violation"
    }
}

# Stop the trace and return the list of ports the port depends on.
# This method must be called after trace_start
proc porttrace::trace_stop {} {
    global os.platform
    if {${os.platform} == "darwin"} {
        global env trace_fifo macosx_version
        foreach var {DYLD_INSERT_LIBRARIES DARWINTRACE_LOG} {
            array unset env $var
            if {$macosx_version eq "10.5"} {
                unsetenv $var
            }
        }

        #kill socket
        tracelib clean

        # Clean up.
        slave_send porttrace::slave_stop

        # Delete the slave.
        delete_slave

        file delete -force $trace_fifo
    }
}

# Private
# Create the slave thread.
proc porttrace::create_slave {workpath trace_fifo} {
    global trace_thread prefix developer_dir registry.path
    # Create the thread.
    set trace_thread [macports_create_thread]

    # The slave thred needs this file and macports 1.0
    thread::send $trace_thread "package require porttrace 1.0"
    thread::send $trace_thread "package require macports 1.0"
    # slave needs ui_{info,warn,debug,error}...
    # make sure to sync this with ../pextlib1.0/tracelib.c!
    thread::send $trace_thread "macports::ui_init debug"
    thread::send $trace_thread "macports::ui_init info"
    thread::send $trace_thread "macports::ui_init warn"
    thread::send $trace_thread "macports::ui_init error"
    # and these variables
    thread::send $trace_thread "set prefix \"$prefix\"; set developer_dir \"$developer_dir\""
    # The slave thread requires the registry package.
    thread::send $trace_thread "package require registry 1.0"
    # and an open registry
    thread::send $trace_thread "registry::open [file join ${registry.path} registry registry.db]"

    # Initialize the slave
    thread::send $trace_thread "porttrace::slave_init $trace_fifo $workpath"

    # Run slave asynchronously
    thread::send -async $trace_thread "porttrace::slave_run"
}

# Private
# Send a command to the thread without waiting for the result.
proc porttrace::slave_send_async {command} {
    global trace_thread

    thread::send -async $trace_thread "$command"
}

# Private
# Send a command to the thread.
proc porttrace::slave_send {command} {
    global trace_thread

    # ui_warn "slave send $command ?"

    thread::send $trace_thread "$command" result
    return $result
}

# Private
# Destroy the thread.
proc porttrace::delete_slave {} {
    global trace_thread

    # Destroy the thread.
    thread::release $trace_thread
}

# Private.
# Slave method to read a line from the trace.
proc porttrace::slave_read_line {chan} {
    global ports_list trace_filemap sandbox_violation_list workpath env

    while 1 {
        # We should never get EOF, actually.
        if {[eof $chan]} {
            break
        }

        # The line is of the form: verb\tpath
        # Get the path by chopping it.
        set theline [gets $chan]

        if {[fblocked $chan]} {
            # Exit the loop.
            break
        }

        set line_length [string length $theline]

        # Skip empty lines.
        if {$line_length > 0} {
            set path_start [expr {[string first "\t" $theline] + 1}]
            set op [string range $theline 0 [expr {$path_start - 2}]]
            set path [string range $theline $path_start [expr {$line_length - 1}]]

            # open/execve
            if {$op eq "open" || $op eq "execve"} {
                # Only work on files.
                if {[file isfile $path]} {
                    # Did we process the file yet?
                    if {![filemap exists trace_filemap $path]} {
                        # Obtain information about this file.
                        set port [registry::file_registered $path]
                        if { $port != 0 } {
                            # Add the port to the list.
                            if {[lsearch -sorted -exact $ports_list $port] == -1} {
                                lappend ports_list $port
                                set ports_list [lsort $ports_list]
                                # Maybe fill trace_filemap for efficiency?
                            }
                        }

                        # Add the file to the tree with port information.
                        # Ignore errors. Errors can occur if a directory was
                        # created where a file once lived.
                        # This doesn't affect existing ports and we just
                        # add this information to speed up port detection.
                        catch {filemap set trace_filemap $path $port}
                    }
                }
            } elseif {$op eq "sandbox_violation"} {
                lappend sandbox_violation_list $path
            }
        }
    }
}

# Private.
# Slave init method.
proc porttrace::slave_init {fifo p_workpath} {
    global ports_list trace_filemap sandbox_violation_list
    # Save the workpath.
    set workpath $p_workpath
    # Create a virtual filemap.
    filemap create trace_filemap
    set ports_list {}
    set sandbox_violation_list {}
    tracelib setname $fifo

    if {[catch {tracelib opensocket} err]} {
        global errorInfo
        ui_warn "Error in tracelib: $err"
        ui_debug "Backtrace: $errorInfo"
    }
}

proc porttrace::slave_run {} {
    if {[catch {tracelib run} err]} {
        global errorInfo
        ui_warn "Error in tracelib: $err"
        ui_debug "Backtrace: $errorInfo"
    }
}

# Private.
# Slave cleanup method.
proc porttrace::slave_stop {} {
    global trace_filemap
    # Close the virtual filemap.
    filemap close trace_filemap
    # Close the pipe (both ends).
}

# Private.
# Slave ports export method.
proc porttrace::slave_get_ports {} {
    global ports_list
    return $ports_list
}

# Private.
# Slave sandbox violations export method.
proc porttrace::slave_get_sandbox_violations {} {
    global sandbox_violation_list
    return $sandbox_violation_list
}

proc porttrace::slave_add_sandbox_violation {path} {
    global sandbox_violation_list
    lappend sandbox_violation_list $path
}
