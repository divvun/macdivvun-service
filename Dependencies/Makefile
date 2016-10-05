ARCHS="x86_64"
FRAMEWORKS = \
	Frameworks/liblzma.framework \
	Frameworks/libarchive.framework \
	Frameworks/tinyxml2.framework \
	Frameworks/libhfstospell.framework \
	Frameworks/libvoikko.framework

DEPS_DIR ?= $(CURDIR)
PREFIX = $(DEPS_DIR)

SDKVERSION := $(MACOSX_DEPLOYMENT_TARGET)
SDKVERSION ?= $(shell xcrun --show-sdk-version)

all: $(FRAMEWORKS)

libarchive: # Cool stub!
xz: # Cool stub!
hfst-ospell: # Cool stub!
tinyxml2: ###
corevoikko/libvoikko: ###

# $(DEPS_DIR)  set by Xcode
# $(ARCHS)	  set by Xcode, but sadly does not include all target architectures

Frameworks/tinyxml2.framework: tinyxml2
	cd $< && cmake -DCMAKE_INSTALL_PREFIX="$(PREFIX)/Static/x86_64" \
		-DCMAKE_MACOSX_RPATH=ON \
		-DBUILD_STATIC_LIBS=ON \
	 	-DBUILD_SHARED_LIBS=OFF \
	&& make \
	&& make install \
	&& rm $(PREFIX)/Static/x86_64/lib/libtinyxml*.dylib \
	&& mkdir -p $(PREFIX)/Frameworks/tinyxml2.framework/Headers \
	&& lipo -create -output $(PREFIX)/Frameworks/tinyxml2.framework/tinyxml2 libtinyxml2.a \
	&& cp tinyxml2.h $(PREFIX)/Frameworks/tinyxml2.framework/Headers

Frameworks/liblzma.framework: xz
	cd $< && autoreconf -fi 2>&1
	cd $< && PREFIX=$(PREFIX) ARCHS=$(ARCHS) SDKVERSION=$(SDKVERSION) \
		$(DEPS_DIR)/autoframework liblzma liblzma.a \
		--disable-xz \
		--disable-xzdec \
		--disable-lzmadec \
		--disable-lzmainfo \
		--disable-lzma-links \
		--disable-scripts \
		--disable-encoders \
		--disable-doc \
		--disable-rpath

Frameworks/libhfstospell.framework: hfst-ospell
	cd $< && PREFIX=$(PREFIX) ARCHS=$(ARCHS) SDKVERSION=$(SDKVERSION) \
		./autogen.sh 2>&1
	cd $< && PREFIX=$(PREFIX) ARCHS=$(ARCHS) SDKVERSION=$(SDKVERSION) \
		$(DEPS_DIR)/autoframework libhfstospell libhfstospell.a \
		--disable-silent-rules \
		--disable-hfst-ospell-office \
		--with-tinyxml2 \
		--without-libxmlpp \
		--enable-zhfst

Frameworks/libarchive.framework: libarchive
	cd $< && autoreconf -fi 2>&1
	cd $< && PREFIX=$(PREFIX) ARCHS=$(ARCHS) SDKVERSION=$(SDKVERSION) CFLAGS="-Wno-error" \
		$(DEPS_DIR)/autoframework libarchive libarchive.a \
		--without-bz2lib \
		--without-lzmadec \
		--without-iconv \
		--without-lzo2 \
		--without-nettle \
		--without-openssl \
		--without-xml2 \
		--without-expat \
		--disable-bsdcpio \
		--disable-bsdtar

Frameworks/libvoikko.framework: corevoikko/libvoikko
	cd $< && ./autogen.sh 2>&1
	cd $< && PREFIX=$(PREFIX) ARCHS=$(ARCHS) SDKVERSION=$(SDKVERSION) PTHREAD_CFLAGS="" \
		$(DEPS_DIR)/autoframework libvoikko libvoikko.a \
		--disable-buildtools \
		--disable-testtools \
		--with-dictionary-path="/Library/Spelling/voikko:/usr/local/share/voikko:/usr/local/lib/voikko"

clean-submodules: xz corevoikko hfst-ospell libarchive tinyxml2
	cd $< && git clean -fdx

clean: clean-submodules
	rm -r Frameworks Static

xcode: all
xcodeclean: clean
xcodeinstall: all
