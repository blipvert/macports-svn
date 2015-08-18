PREFIX=	/opt/local
SRCS=	${PREFIX}/etc/macports/sources.conf
SUDO=	sudo

default: all

all:
	@(cd base && ([ -f Makefile ] || ./standard_configure.sh --prefix=${PREFIX}) && ${MAKE} all)

install: all
	@(cd base && ${SUDO} ${MAKE} install)
	@if egrep -q ^rsync ${SRCS}; then \
	  echo file://`pwd`/dports/ [default] >> ${SRCS}; \
	  sed -i .orig -e 's/^rsync/#rsync/' ${SRCS}; \
	  echo "${SRCS} automatically configured"; \
        fi

selfupdate:: install index

index::
	@(cd dports && portindex -o ${HOME}/.macports${CURDIR}/dports)
	@for f in PortIndex PortIndex.quick; do \
		[ -f dports/$$f ] || \
		ln -sf ${HOME}/.macports${CURDIR}/dports/$$f dports/$$f; done

clean:
	@(cd base && ([ ! -f Makefile ] || ${MAKE} clean))

