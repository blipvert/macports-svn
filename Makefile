all:
	@(cd base; make $@)
clean:
	@(cd base; make $@)
	@portall clean

install:
	@(cd base; make $@)
