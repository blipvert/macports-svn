# et:ts=4
# portfetch.tcl
# $Id: portfetch.tcl,v 1.112 2006/06/10 23:04:29 pguyot Exp $
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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

package provide portfetch 1.0
package require portutil 1.0
package require Pextlib 1.0

set com.apple.fetch [target_new com.apple.fetch fetch_main]
target_init ${com.apple.fetch} fetch_init
target_provides ${com.apple.fetch} fetch
target_requires ${com.apple.fetch} main
target_prerun ${com.apple.fetch} fetch_start

# define options: distname master_sites
options master_sites patch_sites extract.suffix distfiles patchfiles use_zip use_bzip2 dist_subdir \
	fetch.type fetch.user fetch.password fetch.use_epsv \
	master_sites.mirror_subdir patch_sites.mirror_subdir portname \
	cvs.module cvs.root cvs.password cvs.date cvs.tag \
	svn.url svn.tag
	
# XXX we use the command framework to buy us some useful features,
# but this is not a user-modifiable command
commands cvs
commands svn

# Defaults
default extract.suffix .tar.gz
default fetch.type standard

default cvs.cmd {$portutil::autoconf::cvs_path}
default cvs.password ""
default cvs.dir {${workpath}}
default cvs.module {$distname}
default cvs.tag ""
default cvs.date ""
default cvs.env {CVS_PASSFILE=${workpath}/.cvspass}
default cvs.pre_args {"-z9 -f -d ${cvs.root}"}
default cvs.args ""
default cvs.post_args {"${cvs.module}"}

default svn.cmd {svn}
default svn.dir {${workpath}}
default svn.tag ""
default svn.env {}
default svn.pre_args {"--non-interactive"}
default svn.args ""
default svn.post_args {"${svn.url}"}

# Set distfiles
default distfiles {[suffix $distname]}
default dist_subdir {${portname}}

# user name & password
default fetch.user ""
default fetch.password ""
# Use EPSV for FTP transfers
default fetch.use_epsv "yes"

default fallback_mirror_site "opendarwin"
default mirror_sites.listfile {"mirror_sites.tcl"}
default mirror_sites.listpath {"${portresourcepath}/fetch/"}

# Option-executed procedures
option_proc use_bzip2 fix_extract_suffix
option_proc use_zip fix_extract_suffix

proc fix_extract_suffix {option action args} {
    global extract.suffix
    if {[string equal ${action} "set"] && [tbool args]} {
        switch $option {
            use_bzip2 {
                set extract.suffix .tar.bz2
            }
            use_zip {
                set extract.suffix .zip
            }
        }
    }
}

# Name space for internal implementation variables
# Site lists are stored here
namespace eval portfetch { }

set_ui_prefix

# Given a distname, return a suffix based on the use_zip / use_bzip2 / extract.suffix options
proc suffix {distname} {
    global extract.suffix fetch.type
    switch -- "${fetch.type}" {
    	cvs			-
    	svn			{ return "" }
    	standard	-
    	default 	{ return "${distname}${extract.suffix}" }
    }
}

# Given a site url and the name of the distfile, assemble url and
# return it.
proc portfetch::assemble_url {site distfile} {
    if {[string index $site end] != "/"} {
        return "${site}/${distfile}"
    } else {
        return "${site}${distfile}"
    }
}

# XXX
# Helper function for portextract.tcl that strips all tag names from a list
# Used to clean ${distfiles} for setting the ${extract.only} default
proc disttagclean {list} {
    if {"$list" == ""} {
        return $list
    }
    foreach name $list {
        lappend val [getdistname $name]
    }
    return $val
}

# For a given mirror site type, e.g. "gnu" or "x11", check to see if there's a
# pre-registered set of sites, and if so, return them.
proc mirror_sites {mirrors tag subdir} {
    global UI_PREFIX portname portresourcepath mirror_sites.listfile mirror_sites.listpath dist_subdir
    source ${mirror_sites.listpath}${mirror_sites.listfile}
    if {![info exists portfetch::mirror_sites::sites($mirrors)]} {
        ui_warn "[format [msgcat::mc "No mirror sites on file for class %s"] $mirrors]"
        return {}
    }
    
    set ret [list]
    foreach element $portfetch::mirror_sites::sites($mirrors) {
	
	# here we have the chance to take a look at tags, that possibly
	# have been assigned in mirror_sites.tcl
	set splitlist [split $element :]
	if {[llength $splitlist] > 1} {
	    set element "[lindex $splitlist 0]:[lindex $splitlist 1]" 
	    set mirror_tag "[lindex $splitlist 2]"
	}

	if {$mirror_tag == "mirror"} {
		set thesubdir ${dist_subdir}
	} elseif {$subdir == "" && $mirror_tag != "nosubdir"} {
		set thesubdir ${portname}
	} else {
		set thesubdir ${subdir}
	}
	
	if {"$tag" != ""} {
	    eval append element "${thesubdir}:${tag}"
	} else {
	    eval append element "${thesubdir}"
	}
        eval lappend ret $element
    }
    
    return $ret
}

# Checks all files and their tags to assemble url lists for later fetching
# sites tags create variables in the portfetch:: namespace containing all sites
# within that tag distfiles are added in $site $distfile format, where $site is
# the name of a variable in the portfetch:: namespace containing a list of fetch
# sites
proc checkfiles {args} {
    global distfiles patchfiles all_dist_files patch_sites fetch_urls \
	master_sites filespath master_sites.mirror_subdir \
        patch_sites.mirror_subdir fallback_mirror_site env
    
    append master_sites " ${fallback_mirror_site}"
    if {[info exists env(MASTER_SITE_LOCAL)]} {
	set master_sites [concat $env(MASTER_SITE_LOCAL) $master_sites]
    }
    
    append patch_sites " ${fallback_mirror_site}"
    if {[info exists env(PATCH_SITE_LOCAL)]} {
	set patch_sites [concat $env(PATCH_SITE_LOCAL) $patch_sites]
    }

    foreach list {master_sites patch_sites} {
        upvar #0 $list uplist
        if {![info exists uplist]} {
            continue
        }
        
        set site_list [list]
        foreach site $uplist {
            if {[regexp {([a-zA-Z]+://.+)} $site match site]} {
                set site_list [concat $site_list $site]
            } else {
	    	set splitlist [split $site :]
		if {[llength $splitlist] > 3 || [llength $splitlist] <1} {
                    ui_error [format [msgcat::mc "Unable to process mirror sites for: %s, ignoring."] $site]
		}
		set mirrors "[lindex $splitlist 0]"
		set subdir "[lindex $splitlist 1]"
		set tag "[lindex $splitlist 2]"
                if {[info exists $list.mirror_subdir]} {
                    append subdir "[set ${list}.mirror_subdir]"
                }
                set site_list [concat $site_list [mirror_sites $mirrors $tag $subdir]]
            }
        }
        
        foreach site $site_list {
	    if {[regexp {([a-zA-Z]+://.+/?):([0-9A-Za-z_-]+)$} $site match site tag]} {
                lappend portfetch::$tag $site
            } else {
                lappend portfetch::$list $site
            }
        }
    }
    
    if {[info exists patchfiles]} {
	foreach file $patchfiles {
	    if {![file exists $filespath/$file]} {
		set distsite [getdisttag $file]
		set file [getdistname $file]
		lappend all_dist_files $file
		if {$distsite != ""} {
		    lappend fetch_urls $distsite $file
		} elseif {[info exists patch_sites]} {
		    lappend fetch_urls patch_sites $file
		} else {
		    lappend fetch_urls master_sites $file
		}
	    }
	}
    }
    
    foreach file $distfiles {
	if {![file exists $filespath/$file]} {
	    set distsite [getdisttag $file]
	    set file [getdistname $file]
	    lappend all_dist_files $file
	    if {$distsite != ""} {
		lappend fetch_urls $distsite $file
	    } else {
		lappend fetch_urls master_sites $file
	    }
	}
    }
}

# Perform a CVS login and fetch, storing the CVS login
# information in a custom .cvspass file
proc cvsfetch {args} {
    global workpath cvs.env cvs.cmd cvs.args cvs.post_args 
    global cvs.root cvs.date cvs.tag cvs.password

    set cvs.args "co ${cvs.args}"
    if {[string length ${cvs.tag}]} {
	set cvs.args "${cvs.args} -r ${cvs.tag}"
    }

    if {[string length ${cvs.date}]} {
	set cvs.args "${cvs.args} -D ${cvs.date}"
    }

    if {[regexp ^:pserver: ${cvs.root}]} {
	set savecmd ${cvs.cmd}
	set saveenv ${cvs.env}
	set saveargs ${cvs.args}
	set savepost_args ${cvs.post_args}
	set cvs.cmd "echo ${cvs.password} | /usr/bin/env ${cvs.env} $portutil::autoconf::cvs_path"
	set cvs.env ""
	set cvs.args login
	set cvs.post_args ""
	if {[catch {system -notty "[command cvs] 2>&1"} result]} {
	    return -code error [msgcat::mc "CVS login failed"]
	}
	set cvs.cmd ${savecmd}
	set cvs.env ${saveenv}
	set cvs.args ${saveargs}
	set cvs.post_args ${savepost_args}
    } else {
	set env(CVS_RSH) ssh
    }

    if {[catch {system "[command cvs] 2>&1"} result]} {
	return -code error [msgcat::mc "CVS check out failed"]
    }

    return 0
}

# Perform an svn fetch
proc svnfetch {args} {
    global workpath prefix
    global svn.env svn.cmd svn.args svn.post_args svn.tag svn.url
    
    # Look for the svn command, either in the path or in the prefix
    set goodcmd 0
    foreach svncmd "${svn.cmd} ${prefix}/bin/svn svn" {
 	if { [file executable ${svncmd}] } {
 	   	  set svn.cmd $svncmd
 	   	  set goodcmd 1
 	      break;
 	   }
    }
    if { !$goodcmd } {
    	ui_error "The subversion tool (svn) is required to fetch ${svn.url}."
    	ui_error "Please install the subversion port before proceeding."
		return -code error [msgcat::mc "Subversion check out failed"]
    }
    
    set svn.args "checkout ${svn.args}"
    if {[string length ${svn.tag}]} {
		set svn.args "${svn.args} -r ${svn.tag}"
    }

    if {[catch {system "[command svn] 2>&1"} result]} {
		return -code error [msgcat::mc "Subversion check out failed"]
    }

    return 0
}

# Perform a standard fetch, assembling fetch urls from
# the listed url varable and associated distfile
proc fetchfiles {args} {
	global distpath all_dist_files UI_PREFIX fetch_urls
	global fetch.user fetch.password fetch.use_epsv
	global distfile site
	global portverbose

	if {![file isdirectory $distpath]} {
		if {[catch {file mkdir $distpath} result]} {
			return -code error [format [msgcat::mc "Unable to create distribution files path: %s"] $result]
		}
	}
	
	set fetch_options {}
	if {[string length ${fetch.user}] || [string length ${fetch.password}]} {
		lappend fetch_options -u
		lappend fetch_options "${fetch.user}:${fetch.password}"
	}
	if {${fetch.use_epsv} != "yes"} {
		lappend fetch_options "--disable-epsv"
	}
	if {$portverbose == "yes"} {
		lappend fetch_options "-v"
	}
	
	foreach {url_var distfile} $fetch_urls {
		if {![file isfile $distpath/$distfile]} {
			ui_info "$UI_PREFIX [format [msgcat::mc "%s doesn't seem to exist in %s"] $distfile $distpath]"
			if {![file writable $distpath]} {
				return -code error [format [msgcat::mc "%s must be writable"] $distpath]
			}
			global portfetch::$url_var
			if {![info exists $url_var]} {
				ui_error [format [msgcat::mc "No defined site for tag: %s, using master_sites"] $url_var]
				set url_var master_sites
				global portfetch::$url_var
			}
			unset -nocomplain fetched
			foreach site [set $url_var] {
				ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to fetch %s from %s"] $distfile $site]"
				set file_url [portfetch::assemble_url $site $distfile]
				set effectiveURL ""
				if {![catch {eval curl fetch --effective-url effectiveURL $fetch_options {$file_url} ${distpath}/${distfile}.TMP} result] &&
					![catch {system "mv ${distpath}/${distfile}.TMP ${distpath}/${distfile}"}]} {

					# Special hack to check for sourceforge mirrors, which don't return a proper error code on failure
					if {![string equal $effectiveURL $file_url] &&
						[string match "*sourceforge*" $file_url] &&
						[string match "*failedmirror*" $effectiveURL]} {
						
						# *SourceForge hackage in effect*
						# The url seen by curl seems to have been a redirect to the sourceforge mirror page
						ui_debug "[msgcat::mc "Fetching from sourceforge mirror failed"]"
						exec rm -f ${distpath}/${distfile}.TMP
						
						# Continue on to try the next mirror, if any
					} else {
					
						# Successful fetch
						set fetched 1
						break
					
					}

				} else {
					ui_debug "[msgcat::mc "Fetching failed:"]: $result"
					exec rm -f ${distpath}/${distfile}.TMP
				}
			}
			if {![info exists fetched]} {
				return -code error [msgcat::mc "fetch failed"]
			}
		}
	}
    return 0
}

# Utility function to delete fetched files.
proc fetch_deletefiles {args} {
	global distpath fetch_urls
	foreach {url_var distfile} $fetch_urls {
		if {[file isfile $distpath/$distfile]} {
			exec rm -f ${distpath}/${distfile}
		}
	}
}

# Utility function to add files to a list of fetched files.
proc fetch_addfilestomap {filemapname} {
	global distpath fetch_urls $filemapname
	foreach {url_var distfile} $fetch_urls {
		if {[file isfile $distpath/$distfile]} {
			filemap set $filemapname $distpath/$distfile 1
		}
	}
}

# Initialize fetch target, calling checkfiles if neccesary
proc fetch_init {args} {
    global distfiles distname distpath all_dist_files dist_subdir fetch.type
    
    if {[info exist distpath] && [info exists dist_subdir]} {
	set distpath ${distpath}/${dist_subdir}
    }
    if {"${fetch.type}" == "standard"} {
        checkfiles
    }
}

proc fetch_start {args} {
    global UI_PREFIX portname
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Fetching %s"] $portname]"
}

# Main fetch routine
# If all_dist_files is not populated and $fetch.type == standard, then
# there are no files to download. Otherwise, either do a cvs checkout
# or call the standard fetchfiles procedure
proc fetch_main {args} {
    global distname distpath all_dist_files fetch.type

    # Check for files, download if neccesary
    if {![info exists all_dist_files] && "${fetch.type}" == "standard"} {
        return 0
    }
    
    # Fetch the files
    switch -- "${fetch.type}" {
    	cvs		{ return [cvsfetch] }
    	svn		{ return [svnfetch] }
    	standard -
    	default	{ return [fetchfiles] }
    }
}
