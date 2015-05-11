#!/bin/sh
# Run this to generate all the initial makefiles, etc.

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

PKG_NAME="gtksourceview"

(test -f $srcdir/configure.ac \
  && test -f $srcdir/README \
  && test -d $srcdir/gtksourceview) || {
    echo -n "**Error**: Directory "\`$srcdir\'" does not look like the"
    echo " top-level $PKG_NAME directory"
    exit 1
}

which gnome-autogen.sh || {
    echo "You need to install gnome-common from GNOME Git (or from"
    echo "your OS vendor's package manager)."
    exit 1
}

USE_GNOME2_MACROS=1 . gnome-autogen.sh
