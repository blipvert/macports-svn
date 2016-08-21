#!/bin/sh
# Run this to generate all the initial makefiles, etc.

PKG_NAME="Gnumeric"

test -n "$srcdir" || srcdir=$(dirname "$0")
test -n "$srcdir" || srcdir=.

olddir=$(pwd)

(test -f $srcdir/configure.ac \
  && test -d $srcdir/src \
  && test -f $srcdir/src/gnumeric.h) || {
    echo -n "**Error**: Directory "\`$srcdir\'" does not look like the"
    echo " top-level gnumeric directory"
    exit 1
}

cd $srcdir
aclocal --install || exit 1
glib-gettextize --force --copy || exit 1
gtkdocize --copy || exit 1
intltoolize --force --copy --automake || exit 1
autoreconf --verbose --force --install || exit 1
cd $olddir


# We have our own copy of Makefile.in.in generated October 2008.
# One of the reasons why we need a local copy is that
# we generate po-functions/Makefile.in.in from it, which is committed to
# SVN, so this file cannot depend on the versions of the tools which the
# developers have installed.
#
echo "Creating po/Makefile.in.in and po-functions/Makefile.in.in."
#rm -f $srcdir/po/Makefile.in.in $srcdir/po-functions/Makefile.in.in
rm -f $srcdir/po-functions/Makefile.in.in
#cp $srcdir/po/Makefile.in.in.own $srcdir/po/Makefile.in.in
sed -e '/^GETTEXT_PACKAGE =/s/@GETTEXT_PACKAGE@$/@GETTEXT_PACKAGE@-functions/' \
    -e 's|$(srcdir)/LINGUAS|$(top_srcdir)/po/LINGUAS|g' \
    -e '/^GETTEXT_PACKAGE =/a\
XGETTEXT_KEYWORDS = --keyword --keyword=F_' \
    -e '/^EXTRA_DISTFILES/s/ LINGUAS//' \
$srcdir/po/Makefile.in.in >$srcdir/po-functions/Makefile.in.in

echo "Creating po-functions/POTFILES.{in,skip}."
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


if [ "$NOCONFIGURE" = "" ]; then
        $srcdir/configure "$@" || exit 1

        if [ "$1" = "--help" ]; then exit 0 else
                echo "Now type 'make' to compile $PKG_NAME" || exit 1
        fi
else
        echo "Skipping configure process."
fi
