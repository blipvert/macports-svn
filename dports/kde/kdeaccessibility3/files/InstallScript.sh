#!/bin/sh -e

        export PREFIX="%p"
        . ./environment-helper.sh

#darwinports
	export UNSERMAKE="no"

        ./build-helper.sh install %N %v %r make -j1 install DESTDIR=%d

        mkdir -p %i/share/doc/installed-packages
        touch %i/share/doc/installed-packages/%N
        touch %i/share/doc/installed-packages/%N-base

        rm -rf %i/share/doc/kde/en/kmouth
        install -d -m 755 %i/share/config
        cat <<EOF #!/bin/sh -e
END > %i/share/config/kttsdrc
[FreeTTS]
FreeTTSJarPath=%p/share/java/freetts/freetts.jar

[GStreamerPlayer]
SinkName=

[General]
AudioOutputMethod=0
AudioStretchFactor=100
EmbedInSysTray=true
EnableKttsd=true
Notify=false
NotifyPassivePopupsOnly=false
ShowMainWindowOnStartup=true
TalkerIDs=1
TextPostMsg=Resuming text.
TextPostMsgEnabled=true
TextPostSnd=\$HOME
TextPostSndEnabled=false
TextPreMsg=Text interrupted. Message.
TextPreMsgEnabled=true
TextPreSnd=\$HOME
TextPreSndEnabled=false

[Talker_1]
FreeTTSJarPath=%p/share/java/freetts/freetts.jar
PlugIn=FreeTTS
TalkerCode=<voice lang="en_US" name="fixed" gender="neutral" /><prosody volume="medium" rate="medium" /><kttsd synthesizer="FreeTTS" />
END
