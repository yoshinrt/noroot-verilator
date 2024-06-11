# -*- tab-width: 4 -*-

SRC_DIR						= source
DST_DIR						= ${HOME}/local
export PATH					:= ${DST_DIR}/bin:${PATH}
export OPENSSL_LIBS			:= ${DST_DIR}/lib64/libssl.so
export LIBRARY_PATH			:= ${DST_DIR}/lib:${DST_DIR}/lib64
export LD_LIBRARY_PATH		:= ${DST_DIR}/lib64:${DST_DIR}/lib:$LD_LIBRARY_PATH
export C_INCLUDE_PATH		:= ${DST_DIR}/include
export CPLUS_INCLUDE_PATH	:= ${DST_DIR}/include

SRCS	= \
	https://www.python.org/ftp/python/3.12.3/Python-3.12.3.tgz \
	https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz \
	https://github.com/tukaani-project/xz/releases/download/v5.6.2/xz-5.6.2.tar.bz2 \
	https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz \
	https://invisible-island.net/archives/ncurses/ncurses-5.9.tar.gz \
	ftp://ftp.cwru.edu/pub/bash/readline-8.2.tar.gz \
	https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.gz \
	https://github.com/westes/flex/files/981163/flex-2.6.4.tar.gz \
	https://ftp.gnu.org/gnu/bison/bison-3.8.tar.gz \
	https://ftp.tsukuba.wide.ad.jp/software/gcc/releases/gcc-14.1.0/gcc-14.1.0.tar.xz \
	https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz \
	https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz \
	https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz \
	https://github.com/gperftools/gperftools/releases/download/gperftools-2.15/gperftools-2.15.tar.gz \
	https://ftp.gnu.org/gnu/help2man/help2man-1.49.3.tar.xz \
	verilator::https://github.com/verilator/verilator/archive/refs/tags/v5.024.tar.gz \
	systemc::https://github.com/accellera-official/systemc/archive/refs/tags/3.0.0.tar.gz \
	https://github.com/Kitware/CMake/releases/download/v3.29.3/cmake-3.29.3.tar.gz

##############################################################################

para:
	nice -n 19 $(MAKE) -j8 all 2>&1 | tee log

all: b.verilator

download:
	@mkdir -p $(SRC_DIR); cd $(SRC_DIR); \
	rm -f fail-list; \
	for source in $(SRCS); do \
		url=$${source#*::}; \
		exname=$${source%%::*}; \
		filename=`basename $$url`; \
		if [ $$url != $$exname ]; then filename=$$exname-$$filename; fi; \
		if [ ! -e $$filename ]; then wget -P . --no-check-certificate $$url; \
			if [ $$url != $$exname ]; then mv `basename $$url` $$filename; fi; \
			if [ ! -e $$filename ]; then echo $$filename >> fail-list; fi; \
		fi; \
	done; \
	if [ -e fail-list ]; then \
		echo "=== Download FAILED ==="; \
		cat fail-list; \
		echo "======================="; \
		rm -f fail-list; \
	else \
		echo "Download completed successfully."; \
	fi

##############################################################################

b.%:
	if [ ! -d $*?* ]; then tar xf ${SRC_DIR}/$**; fi
	cd $*?*; \
		./configure --prefix=${DST_DIR}; \
		$(MAKE); $(MAKE) install
	touch $@

git-clone:
	repo=$(REPO); repo=`basename $${repo#*/} .git`; echo $$repo; \
	if [ ! -d $$repo-* ]; then \
		git clone $(REPO) $$repo-build; \
		cd $$repo-*; \
		git reset --hard $(REV); \
	fi

##############################################################################

b.bzip2:
	if [ ! -d bzip2-* ]; then tar xf ${SRC_DIR}/bzip2-*.tar.*; fi
	cd bzip2-*; \
	make -f Makefile-libbz2_so clean; make -f Makefile-libbz2_so; cp -f libbz2.so.1.0.8 ${DST_DIR}/lib; \
	make clean install PREFIX=${DST_DIR}
	cd ${DST_DIR}/lib; ln -s libbz2.so.1.0.8 libbz2.so.1.0; ln -s libbz2.so.1.0 libbz2.so.1; ln -s libbz2.so.1 libbz2.so
	touch $@

b.readline: b.ncurses

b.python: b.bzip2 b.libffi b.xz b.readline
	if [ ! -d Python-* ]; then tar xf ${SRC_DIR}/Python-*.tgz; fi
	cd Python-*; \
	./configure --prefix=${DST_DIR} --with-openssl=${DST_DIR} --with-openssl-rpath=${DST_DIR}/lib; \
	$(MAKE); $(MAKE) install
	touch $@

##############################################################################

b.flex: b.bison

##############################################################################

b.gcc: b.gmp b.mpfr b.mpc
	if [ ! -d gcc-* ]; then tar xf ${SRC_DIR}/gcc-*.tar.*; fi
	cd gcc-*; \
	mkdir -p objdir; cd objdir; \
	../configure --prefix=${DST_DIR} --enable-languages=c,c++; \
	$(MAKE); $(MAKE) install
	touch $@

##############################################################################

b.BLAKE3:
	$(MAKE) git-clone REPO=https://github.com/BLAKE3-team/BLAKE3.git REV=1.5.1

b.ccache: b.cmake b.BLAKE3
	$(MAKE) git-clone REPO=https://github.com/ccache/ccache.git REV=v4.10

##############################################################################

b.verilator: b.autoconf b.flex b.gcc b.help2man b.systemc #b.ccache b.gperftools
	if [ ! -d verilator?* ]; then tar xf ${SRC_DIR}/verilator*; fi
	cd verilator?*; \
	autoconf; \
	./configure --prefix=${DST_DIR}; \
	$(MAKE); $(MAKE) install
	touch $@

##############################################################################

clean:
	rm -rf b.*
