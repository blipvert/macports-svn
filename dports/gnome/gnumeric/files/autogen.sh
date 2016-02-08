#!/bin/sh
# Run this to generate all the initial makefiles, etc.

PKG_NAME="Gnumeric"

REQUIRED_AUTOMAKE_VERSION=1.9.0
REQUIRED_LIBTOOL_VERSION=1.4.3

# We use the XGETTEXT_KEYWORDS variable, thus we require:
REQUIRED_INTLTOOL_VERSION=0.29

# We require Automake 1.7.2, which requires Autoconf 2.54.
# (It needs _AC_AM_CONFIG_HEADER_HOOK, for example.)
REQUIRED_AUTOCONF_VERSION=2.54

USE_GNOME2_MACROS=1
USE_COMMON_DOC_BUILD=yes

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

(test -f $srcdir/configure.ac \
  && test -d $srcdir/src \
  && test -f $srcdir/src/gnumeric.h) || {
    echo -n "**Error**: Directory "\`$srcdir\'" does not look like the"
    echo " top-level gnumeric directory"
    exit 1
}

ifs_save="$IFS"; IFS=":"
for dir in $PATH ; do
  IFS="$ifs_save"
  test -z "$dir" && dir=.
  if test -f "$dir/gnome-autogen.sh" ; then
    gnome_autogen="$dir/gnome-autogen.sh"
    gnome_datadir=`echo $dir | sed -e 's,/bin$,/share,'`
    break
  fi
done

if test -z "$gnome_autogen" ; then
  echo "You need to install the gnome-common module and make"
  echo "sure the gnome-autogen.sh script is in your \$PATH."
  exit 1
fi

GNOME_DATADIR="$gnome_datadir"

# Dont't run configure yet, ...
GNM_NOCONFIGURE=$NOCONFIGURE
NOCONFIGURE=1
. $gnome_autogen

# We have our own copy of Makefile.in.in generated October 2008.
# One of the reasons why we need a local copy is that
# we generate po-functions/Makefile.in.in from it, which is committed to
# SVN, so this file cannot depend on the versions of the tools which the
# developers have installed.
#
printbold "Creating po/Makefile.in.in and po-functions/Makefile.in.in."
#rm -f $srcdir/po/Makefile.in.in $srcdir/po-functions/Makefile.in.in
rm -f $srcdir/po-functions/Makefile.in.in
#cp $srcdir/po/Makefile.in.in.own $srcdir/po/Makefile.in.in
sed -e '/^GETTEXT_PACKAGE =/s/@GETTEXT_PACKAGE@$/@GETTEXT_PACKAGE@-functions/' \
    -e 's|$(srcdir)/LINGUAS|$(top_srcdir)/po/LINGUAS|g' \
    -e '/^GETTEXT_PACKAGE =/a\
XGETTEXT_KEYWORDS = --keyword --keyword=F_' \
    -e '/^EXTRA_DISTFILES/s/ LINGUAS//' \
$srcdir/po/Makefile.in.in >$srcdir/po-functions/Makefile.in.in

printbold "Creating po-functions/POTFILES.{in,skip}."
rm -f $srcdir/po-functions/POTFILES.in $srcdir/po-functions/POTFILES.skip
# This regex matches names of XML files:
xml_file_name='^((schemas|templates)/.+|[^/]+)\.in$|\.(glade|xml)(\.in)?$'
( echo "# Generated by autogen.sh; do not edit."
  egrep -v "^#|$xml_file_name" $srcdir/po/POTFILES.in
) >$srcdir/po-functions/POTFILES.in
( echo "# Generated by autogen.sh; do not edit."
  test -f $srcdir/po/POTFILES.skip && grep -v '^#' $srcdir/po/POTFILES.skip
  egrep "$xml_file_name" $srcdir/po/POTFILES.in
) >$srcdir/po-functions/POTFILES.skip

# ... and then proceed.
if test "x$GNM_NOCONFIGURE" = x; then
    printbold Running $srcdir/configure $conf_flags "$@" ...
    $srcdir/configure $conf_flags "$@" \
        && echo Now type \`make\' to compile $PKG_NAME || exit 1
fi
