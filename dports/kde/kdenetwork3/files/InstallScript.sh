#!/bin/sh -e

        export PREFIX="%p"
        . ./environment-helper.sh

        ./build-helper.sh install %N %v %r make -j1 install DESTDIR=%d

        mkdir -p %i/share/doc/installed-packages
        touch %i/share/doc/installed-packages/%N
        touch %i/share/doc/installed-packages/%N-base
        touch %i/share/doc/installed-packages/%N-common

        rm -rf %i/share/doc/kde/en/kcontrol/kxmlrpcd
        rm -rf %i/share/doc/kde/en/kppp
        rm -rf %i/share/doc/kde/en/kwifimanager

        find %i/share/apps/kopete -type d -name CVS -exec rm -rf {} \; || :
