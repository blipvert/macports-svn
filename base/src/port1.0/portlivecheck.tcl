# et:ts=4
# portlivecheck.tcl
#
# $Id: portlivecheck.tcl,v 1.6 2006/04/17 07:06:51 pguyot Exp $
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

package provide portlivecheck 1.0
package require portutil 1.0
package require portfetch 1.0

set com.apple.livecheck [target_new com.apple.livecheck livecheck_main]
target_runtype ${com.apple.livecheck} always
target_state ${com.apple.livecheck} no
target_provides ${com.apple.livecheck} livecheck
target_requires ${com.apple.livecheck} main

# define options
options livecheck.distfiles_check livecheck.url livecheck.update_check livecheck.md5 livecheck.regex livecheck.name livecheck.version

# defaults
default livecheck.distfiles_check moddate
default livecheck.url {$homepage}
default livecheck.update_check freshmeat
default livecheck.md5 ""
default livecheck.regex ""
default livecheck.name {$name}
default livecheck.version {$version}

proc livecheck_main {args} {
	global livecheck.distfiles_check livecheck.url livecheck.update_check livecheck.md5 livecheck.regex livecheck.name livecheck.version
	global fetch.type
	global homepage portname portpath workpath
	
	set updated 0
	set updated_version "unknown"

	set tempfile ${workpath}/livecheck.TMP
	set port_moddate [file mtime ${portpath}/Portfile]

	ui_debug "Portfile modification date is [clock format $port_moddate]"
	ui_debug "Port (livecheck) version is ${livecheck.version}"

	# Check the distfiles if it's a regular fetch phase.
	if {"${livecheck.distfiles_check}" != "none"
		&& "${fetch.type}" == "standard"} {
		# portfetch 1.0::checkfiles sets fetch_urls list.
		global fetch_urls
		checkfiles
		
		# Check all the files.
		foreach {url_var distfile} $fetch_urls {
			global portfetch::$url_var
			if {![info exists $url_var]} {
				ui_error [format [msgcat::mc "No defined site for tag: %s, using master_sites"] $url_var]
				set url_var master_sites
				global portfetch::$url_var
			}
			if {${livecheck.distfiles_check} == "moddate"} {
				set count 0
				foreach site [set $url_var] {
					ui_debug [format [msgcat::mc "Checking %s from %s"] $distfile $site]
					set file_url [portfetch::assemble_url $site $distfile]
					if {[catch {set urlnewer [curl isnewer $file_url $port_moddate]} error]} {
						ui_warn "couldn't fetch $file_url for $portname ($error)"
					} else {
						if {$urlnewer} {
							ui_warn "port $portname: $file_url is newer than portfile"
						}
						incr count
					}
				}
				if {$count == 0} {
					ui_error "no mirror had $distfile for $portname"
				}
			} else {
				ui_error "unknown livecheck.distfiles_check ${livecheck.distfiles_check}"
				break
			}
		}
	}
	
	# Perform the check depending on the type.
	if {"${livecheck.update_check}" == "freshmeat"} {
		if {![info exists homepage] || [string equal "${livecheck.url}" "${homepage}"]} {
			set livecheck.url "http://freshmeat.net/projects-xml/${livecheck.name}/${livecheck.name}.xml"
		}
		if {"${livecheck.regex}" == ""} {
			set livecheck.regex "<latest_release_version>(.*)</latest_release_version>"
		}
		set livecheck.update_check "regex"
	}
	
	switch ${livecheck.update_check} {
		"regex" {
			if {[catch {curl fetch ${livecheck.url} $tempfile} error]} {
				ui_error "cannot check if $portname was updated ($error)"
			} else {
				# let's extract the version from the file.
				set chan [open $tempfile "r"]
				set updated -1
				while {1} {
					if {[gets $chan line] < 0} {
						break
					}
					set the_re [eval "concat ${livecheck.regex}"]
					puts $the_re
					if {[regexp $the_re $line line updated_version]} {
						if {$updated_version != ${livecheck.version}} {
							set updated 1
						} else {
							set updated 0
						}
						break
					}
				}
				if {$updated < 0} {
					ui_error "cannot check if $portname was updated (regex didn't match)"
				}
			}
		}
		"md5" {
			if {[catch {curl fetch ${livecheck.url} $tempfile} error]} {
				ui_error "cannot check if $portname was updated ($error)"
			} else {
				# let's compute the md5 sum.
				set dist_md5 [md5 file $tempfile]
				if {$dist_md5 != ${livecheck.md5}} {
					ui_debug "md5sum for ${livecheck.url}: $dist_md5"
					set updated 1
				}
			}
		}
		"moddate" {
			set port_moddate [file mtime ${portpath}/Portfile]
			if {[catch {set updated [curl isnewer ${livecheck.url} $port_moddate]} error]} {
				ui_error "cannot check if $portname was updated ($error)"
			} else {
				if {!$updated} {
					ui_debug "${livecheck.url} is older than Portfile"
				}
			}
		}
		"none" {
		}
		default {
			ui_error "unknown livecheck.update_check ${livecheck.update_check}"
		}
	}

	file delete -force $tempfile

	if {${livecheck.update_check} != "none"} {
		if {$updated > 0} {
			ui_msg "$portname seems to have been updated (port version: ${livecheck.version}, new version: $updated_version)"
		} elseif {$updated == 0} {
			ui_debug "$portname seems to be up to date"
		}
	}
}
