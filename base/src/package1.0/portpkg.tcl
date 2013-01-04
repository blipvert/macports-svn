# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portpkg.tcl
# $Id$
#
# Copyright (c) 2005, 2007 - 2012 The MacPorts Project
# Copyright (c) 2002 - 2003 Apple Inc.
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
# 3. Neither the name of Apple Inc. nor the names of its contributors
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

package provide portpkg 1.0
package require portutil 1.0

set org.macports.pkg [target_new org.macports.pkg portpkg::pkg_main]
target_runtype ${org.macports.pkg} always
target_provides ${org.macports.pkg} pkg
target_requires ${org.macports.pkg} archivefetch unarchive destroot
target_prerun ${org.macports.pkg} portpkg::pkg_start

namespace eval portpkg {
}

# define options
options package.type package.destpath package.flat package.resources package.scripts

# Set defaults
default package.destpath {${workpath}}
default package.resources {${workpath}/pkg_resources}
default package.scripts  {${workpath}/pkg_scripts}
# Need productbuild to make flat packages really work
default package.flat     {[expr [vercmp $macosx_deployment_target 10.6] >= 0]}

set_ui_prefix

proc portpkg::pkg_start {args} {
    global packagemaker_path portpkg::packagemaker \
           portpkg::language xcodeversion portpath porturl \
           package.resources package.scripts package.flat \
           subport version revision description long_description \
           homepage workpath os.major

    if {![info exists packagemaker_path]} {
        if {[vercmp $xcodeversion 4.3] >= 0} {
            set packagemaker_path /Applications/PackageMaker.app
            if {![file exists $packagemaker_path]} {
                ui_warn "PackageMaker.app not found; you may need to install it or set packagemaker_path in macports.conf"
            }
        } else {
            set packagemaker_path "[option developer_dir]/Applications/Utilities/PackageMaker.app"
        }
    }
    set packagemaker "${packagemaker_path}/Contents/MacOS/PackageMaker"

    set language "English"
    file mkdir "${package.resources}/${language}.lproj"
    file attributes "${package.resources}/${language}.lproj" -permissions 0755
    file mkdir ${package.scripts}
    file attributes ${package.scripts} -permissions 0755

    # long_description, description, or homepage may not exist
    foreach variable {long_description description homepage} {
        if {![info exists $variable]} {
            set pkg_$variable ""
        } else {
            set pkg_$variable [set $variable]
        }
    }
    write_welcome_html ${package.resources}/${language}.lproj/Welcome.html $subport $version $revision $pkg_long_description $pkg_description $pkg_homepage
    file copy -force -- [getportresourcepath $porturl "port1.0/package/background.tiff"] ${package.resources}/${language}.lproj/background.tiff

    if {${package.flat} && ${os.major} >= 9} {
        write_distribution "${workpath}/Distribution" $subport $version $revision
    }
}

proc portpkg::pkg_main {args} {
    global subport epoch version revision UI_PREFIX

    ui_msg "$UI_PREFIX [format [msgcat::mc "Creating pkg for %s-%s_%s_%s"] ${subport} ${epoch} ${version} ${revision}]"

    if {[getuid] == 0 && [geteuid] != 0} {
        elevateToRoot "pkg"
    }

    return [package_pkg $subport $epoch $version $revision]
}

proc portpkg::package_pkg {portname portepoch portversion portrevision} {
    global UI_PREFIX portdbpath destpath workpath prefix description \
    package.flat package.destpath portpath os.version os.major \
    package.resources package.scripts portpkg::packagemaker portpkg::language

    set pkgpath "${package.destpath}/${portname}-${portversion}_${portrevision}.pkg"
    if {[file readable $pkgpath] && ([file mtime ${pkgpath}] >= [file mtime ${portpath}/Portfile])} {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Package for %s-%s_%s_%s is up-to-date"] ${portname} ${portepoch} ${portversion} ${portrevision}]"
        return 0
    }

    foreach dir {etc var tmp} {
        if ([file exists "${destpath}/$dir"]) {
            # certain toplevel directories really are symlinks. leaving them as directories make pax lose the symlinks. that's bad.
            file mkdir "${destpath}/private/${dir}"
            eval file rename [glob ${destpath}/${dir}/*] "${destpath}/private/${dir}"
            delete "${destpath}/${dir}"
        }
    }

    if ([file exists "$packagemaker"]) {

        ui_debug "Calling $packagemaker for $portname pkg"
        if {${os.major} >= 9} {
            if {${package.flat}} {
                set pkgtarget "10.5"
                set pkgresources " --scripts ${package.scripts}"
                set infofile "${workpath}/PackageInfo"
                write_package_info $infofile
            } else {
                set pkgtarget "10.3"
                set pkgresources " --resources ${package.resources} --title \"$portname-$portversion\""
                set infofile "${workpath}/Info.plist"
                write_info_plist $infofile $portname $portversion $portrevision
            }
            set cmdline "PMResourceLocale=${language} $packagemaker --root ${destpath} --out ${pkgpath} ${pkgresources} --info $infofile --target $pkgtarget --domain system --id org.macports.$portname"
            if {${os.major} >= 10} {
                append cmdline " --version ${portversion}.${portrevision}"
                append cmdline " --no-relocate"
            } else {
                # 10.5 Leopard does not use current language, manually specify
                append cmdline " -AppleLanguages \"(${language})\""
            }
            ui_debug "Running command line: $cmdline"
            system $cmdline

            if {${package.flat} && ${os.major} >= 10} {
                # the package we just built is just a component
                set componentpath "[file rootname ${pkgpath}]-component.pkg"
                file rename -force ${pkgpath} ${componentpath}
                # Generate a distribution
                set productbuild [findBinary productbuild]
                set cmdline "$productbuild --resources ${package.resources} --identifier org.macports.${portname} --distribution ${workpath}/Distribution --package-path ${package.destpath} ${pkgpath}"
                ui_debug "Running command line: $cmdline"
                system $cmdline
            }
        } else {
            write_info_plist ${workpath}/Info.plist $portname $portversion $portrevision
            write_description_plist ${workpath}/Description.plist $portname $portversion $description
            system "$packagemaker -build -f ${destpath} -p ${pkgpath} -r ${package.resources} -i ${workpath}/Info.plist -d ${workpath}/Description.plist"
        }

        file delete ${workpath}/Info.plist \
                    ${workpath}/PackageInfo \
                    ${workpath}/Distribution \
                    ${workpath}/Description.plist
        file delete -force ${package.resources} \
                           ${package.scripts}

    } else {

        file mkdir ${pkgpath}/Contents/Resources
        foreach f [glob -directory ${package.resources} *] {
            file copy -force -- $f ${pkgpath}/Contents/Resources
        }

        write_PkgInfo ${pkgpath}/Contents/PkgInfo
        write_info_plist ${pkgpath}/Contents/Info.plist $portname $portversion $portrevision

        system "[findBinary mkbom $portutil::autoconf::mkbom_path] ${destpath} ${pkgpath}/Contents/Archive.bom"
        system "cd ${destpath} && [findBinary pax $portutil::autoconf::pax_path] -x cpio -w -z . > ${pkgpath}/Contents/Archive.pax.gz"

        write_description_plist ${pkgpath}/Contents/Resources/Description.plist $portname $portversion $description
        write_sizes_file ${pkgpath}/Contents/Resources/Archive.sizes ${pkgpath} ${destpath}

    }

    foreach dir {etc var tmp} {
        if ([file exists "${destpath}/private/$dir"]) {
            # restore any directories that were moved, to avoid confusing the rest of the ports system.
            file rename ${destpath}/private/$dir ${destpath}/$dir
        }
    }
    catch {file delete ${destpath}/private}

    return 0
}

proc portpkg::write_PkgInfo {infofile} {
    set infofd [open ${infofile} w+]
    puts $infofd "pmkrpkg1"
    close $infofd
}

proc portpkg::xml_escape {s} {
    regsub -all {&} $s {\&amp;} s
    regsub -all {<} $s {\&lt;} s
    regsub -all {>} $s {\&gt;} s
    return $s
}

proc portpkg::write_info_plist {infofile portname portversion portrevision} {
    set portname [xml_escape $portname]
    set portversion [xml_escape $portversion]
    set portrevision [xml_escape $portrevision]

    set infofd [open ${infofile} w+]
    puts $infofd {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    }
    puts $infofd "<dict>
    <key>CFBundleGetInfoString</key>
    <string>${portname} ${portversion}</string>
    <key>CFBundleIdentifier</key>
    <string>org.macports.${portname}</string>
    <key>CFBundleName</key>
    <string>${portname}</string>
    <key>CFBundleShortVersionString</key>
    <string>${portversion}</string>
    <key>IFMajorVersion</key>
    <integer>${portrevision}</integer>
    <key>IFMinorVersion</key>
    <integer>0</integer>
    <key>IFPkgFlagAllowBackRev</key>
    <true/>
    <key>IFPkgFlagAuthorizationAction</key>
    <string>RootAuthorization</string>
    <key>IFPkgFlagDefaultLocation</key>
    <string>/</string>
    <key>IFPkgFlagInstallFat</key>
    <false/>
    <key>IFPkgFlagIsRequired</key>
    <false/>
    <key>IFPkgFlagRelocatable</key>
    <false/>
    <key>IFPkgFlagRestartAction</key>
    <string>NoRestart</string>
    <key>IFPkgFlagRootVolumeOnly</key>
    <true/>
    <key>IFPkgFlagUpdateInstalledLanguages</key>
    <false/>
    <key>IFPkgFormatVersion</key>
    <real>0.10000000149011612</real>
</dict>
</plist>"
    close $infofd
}

proc portpkg::write_description_plist {infofile portname portversion description} {
    set portname [xml_escape $portname]
    set portversion [xml_escape $portversion]
    set description [xml_escape $description]

    set infofd [open ${infofile} w+]
    puts $infofd {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    }
    puts $infofd "<dict>
    <key>IFPkgDescriptionDeleteWarning</key>
    <string></string>
    <key>IFPkgDescriptionDescription</key>
    <string>${description}</string>
    <key>IFPkgDescriptionTitle</key>
    <string>${portname}</string>
    <key>IFPkgDescriptionVersion</key>
    <string>${portversion}</string>
</dict>
</plist>"
    close $infofd
}

proc portpkg::write_welcome_html {filename portname portversion portrevision long_description description homepage} {
    set fd [open ${filename} w+]
    if {$long_description == ""} {
        set long_description $description
    }

    set portname [xml_escape $portname]
    set portversion [xml_escape $portversion]
    set portrevision [xml_escape $portrevision]
    set long_description [xml_escape $long_description]
    set description [xml_escape $description]
    set homepage [xml_escape $homepage]

    puts $fd "
<html lang=\"en\">
<head>
    <meta http-equiv=\"content-type\" content=\"text/html; charset=iso-8859-1\">
    <title>Install ${portname}</title>
</head>
<body>
<font face=\"Helvetica\"><b>Welcome to the ${portname} for Mac OS X Installer</b></font>
<p>
<font face=\"Helvetica\">${long_description}</font>
<p>"

    if {$homepage != ""} {
        puts $fd "<font face=\"Helvetica\"><a href=\"${homepage}\">${homepage}</a></font><p>"
    }

    puts $fd "<font face=\"Helvetica\">This installer guides you through the steps necessary to install ${portname} ${portversion}_${portrevision} for Mac OS X. To get started, click Continue.</font>
</body>
</html>"

    close $fd
}

proc portpkg::write_sizes_file {sizesfile pkgpath destpath} {

    if {[catch {set numFiles [llength [split [exec [findBinary lsbom $portutil::autoconf::lsbom_path] -s ${pkgpath}/Contents/Archive.bom] "\n"]]} result]} {
        return -code error [format [msgcat::mc "Reading package bom failed: %s"] $result]
    }
    if {[catch {set compressedSize [expr [dirSize ${pkgpath}] / 1024]} result]} {
        return -code error [format [msgcat::mc "Error determining compressed size: %s"] $result]
    }
    if {[catch {set installedSize [expr [dirSize ${destpath}] / 1024]} result]} {
        return -code error [format [msgcat::mc "Error determining installed size: %s"] $result]
    }
    if {[catch {set infoSize [file size ${pkgpath}/Contents/Info.plist]} result]} {
       return -code error [format [msgcat::mc "Error determining plist file size: %s"] $result]
    }
    if {[catch {set bomSize [file size ${pkgpath}/Contents/Archive.bom]} result]} {
        return -code error [format [msgcat::mc "Error determining bom file size: %s"] $result]
    }
    incr installedSize $infoSize
    incr installedSize $bomSize

    set fd [open ${sizesfile} w+]
    puts $fd "NumFiles $numFiles
InstalledSize $installedSize
CompressedSize $compressedSize"
    close $fd
}

proc portpkg::write_package_info {infofile} {
    set infofd [open ${infofile} w+]
    puts $infofd "
<pkg-info install-location=\"/\" relocatable=\"false\" auth=\"root\">
</pkg-info>"
    close $infofd
}

proc portpkg::write_distribution {dfile portname portversion portrevision} {
    global macosx_deployment_target
    set portname [xml_escape $portname]
    set portversion [xml_escape $portversion]
    set dfd [open $dfile w+]
    puts $dfd "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<installer-gui-script minSpecVersion=\"1\">
    <title>${portname}</title>
    <options customize=\"never\"/>
    <allowed-os-versions><os-version min=\"${macosx_deployment_target}\"/></allowed-os-versions>
    <background file=\"background.tiff\" mime-type=\"image/tiff\" alignment=\"bottomleft\" scaling=\"none\"/>
    <welcome mime-type=\"text/html\" file=\"Welcome.html\"/>
    <choices-outline>
        <line choice=\"default\">
            <line choice=\"org.macports.${portname}\"/>
        </line>
    </choices-outline>
    <choice id=\"default\"/>
    <choice id=\"org.macports.${portname}\" visible=\"false\">
        <pkg-ref id=\"org.macports.${portname}\"/>
    </choice>
    <pkg-ref id=\"org.macports.${portname}\">${portname}-${portversion}_${portrevision}-component.pkg</pkg-ref>
</installer-gui-script>
"
    close $dfd
}
