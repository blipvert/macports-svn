# $Id$

namespace eval portfetch::mirror_sites { }

set portfetch::mirror_sites::sites(macports_archives) {
    http://packages.macports.org/:nosubdir
}

set portfetch::mirror_sites::archive_prefix(macports_archives) /opt/local
