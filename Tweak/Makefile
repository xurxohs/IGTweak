# IGTweak — Instagram Modification Dylib
# Compiles an arm64 iOS dylib using Xcode's clang + iPhoneOS SDK

SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
CC  := $(shell xcrun --sdk iphoneos -f clang)
MIN_IOS := 15.0

CFLAGS := \
	-arch arm64 \
	-isysroot $(SDK) \
	-miphoneos-version-min=$(MIN_IOS) \
	-dynamiclib \
	-framework Foundation \
	-framework UIKit \
	-lobjc \
	-O2 \
	-Wall

SRC := IGTweak.m
SRC := IGTweak.m IGTweakDownloadManager.m
OUT := IGTweak.dylib

.PHONY: all clean install

all: $(OUT)
	@echo "✅ Built $(OUT)"
	@file $(OUT)

$(OUT): $(SRC)
	$(CC) $(CFLAGS) -o $@ $(SRC)

clean:
	rm -f $(OUT)

# Copy dylib into the Instagram.app bundle
install: $(OUT)
	cp $(OUT) ../Payload/Instagram.app/Frameworks/$(OUT)
	@echo "✅ Copied $(OUT) to Instagram.app/Frameworks/"
