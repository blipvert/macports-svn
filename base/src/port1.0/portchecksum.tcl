# et:ts=4
# portchecksum.tcl
#
# Copyright (c) 2002 - 2004 Apple Computer, Inc.
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

package provide portchecksum 1.0
package require portutil 1.0

set com.apple.checksum [target_new com.apple.checksum checksum_main]
target_provides ${com.apple.checksum} checksum
target_requires ${com.apple.checksum} main fetch
target_prerun ${com.apple.checksum} checksum_start

options checksums

set_ui_prefix

# dmd5
#
# Returns the expected checksum for the given file.
# If no checksum is found, returns -1.
#
proc dmd5 {file} {
	foreach {name type sum} [option checksums] {
		if {[string equal $name $file]} {
			return $sum
		}
	}

	return -1
}

# checksum_start
#
# Target prerun procedure; simply prints a message about what we're doing.
#
proc checksum_start {args} {
	global UI_PREFIX

	ui_msg "$UI_PREFIX [format [msgcat::mc "Verifying checksum(s) for %s"] [option portname]]"
}

# checksum_main
#
# Target main procedure. Verifies the checksums of all distfiles.
#
proc checksum_main {args} {
	global UI_PREFIX all_dist_files

	# If no files have been downloaded, there is nothing to checksum.
	if {![info exists all_dist_files]} {
		return 0
	}

	# Optimization for the two-argument case for checksums.
	if {[llength [option checksums]] == 2 && [llength $all_dist_files] == 1} {
		option checksums [linsert [option checksums] 0 $all_dist_files]
	}

	set fail no

	foreach distfile $all_dist_files {
		ui_info "$UI_PREFIX [format [msgcat::mc "Checksumming %s"] $distfile]"

		# Calculate the distfile's checksum.
		set checksum [md5 file [file join [option distpath] $distfile]]

		# Find the expected checksum.
		set dchecksum [dmd5 $distfile]

		# Check for missing checksum or a mismatch.
		if {$dchecksum == -1} {
			ui_info "[format [msgcat::mc "No checksum set for %s"] $distfile]"
		} elseif {![string equal $checksum $dchecksum]} {
			ui_info "[format [msgcat::mc "Checksum mismatch for %s"] $distfile]"
		} else {
			continue
		}

		# Print out the actual checksum, and raise the failure flag.
		ui_info "[format [msgcat::mc "File checksum is: %s"] $checksum]"
		set fail yes
	}

	if {[tbool fail]} {
		return -code error "[msgcat::mc "Checksum failure"]"
	}

	return 0
}
