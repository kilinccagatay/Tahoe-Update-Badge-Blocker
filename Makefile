PREFPANE_NAME := BadgePreferencePane.prefPane
BUILD_DIR := build
ARCHS := -arch arm64 -arch x86_64
VERSION := 1.1.0
PACKAGE_NAME := Tahoe-Update-Badge-Blocker-$(VERSION).pkg
PACKAGE_SCRIPTS := $(BUILD_DIR)/package-scripts
OUTPUT_DIR := outputs
PREFPANE_DIR := $(BUILD_DIR)/$(PREFPANE_NAME)
CONTENTS_DIR := $(PREFPANE_DIR)/Contents
PREFERENCE_TOOL := $(BUILD_DIR)/BadgePreferenceTool

.PHONY: all clean install package test uninstall

all: $(CONTENTS_DIR)/MacOS/BadgePreferencePane $(PREFERENCE_TOOL)

$(CONTENTS_DIR)/MacOS/BadgePreferencePane: Sources/BadgePreferencePane/BadgePreferencePane.m Sources/BadgePreferencePane/Info.plist
	mkdir -p "$(CONTENTS_DIR)/MacOS" "$(CONTENTS_DIR)/Resources"
	clang $(ARCHS) -fobjc-arc -bundle -framework Cocoa -framework PreferencePanes \
		-mmacosx-version-min=13.0 Sources/BadgePreferencePane/BadgePreferencePane.m \
		-o "$(CONTENTS_DIR)/MacOS/BadgePreferencePane"
	cp Sources/BadgePreferencePane/Info.plist "$(CONTENTS_DIR)/Info.plist"
	cp /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/Notifications.icns \
		"$(CONTENTS_DIR)/Resources/BadgeIcon.icns"
	cp -R Sources/BadgePreferencePane/Resources/. "$(CONTENTS_DIR)/Resources/"
	codesign --force --sign - "$(PREFPANE_DIR)"

$(PREFERENCE_TOOL): Sources/BadgePreferenceTool/BadgePreferenceTool.m
	mkdir -p "$(BUILD_DIR)"
	clang $(ARCHS) -fobjc-arc -framework Foundation -framework CoreFoundation \
		-mmacosx-version-min=13.0 Sources/BadgePreferenceTool/BadgePreferenceTool.m \
		-o "$(PREFERENCE_TOOL)"
	codesign --force --sign - "$(PREFERENCE_TOOL)"

install: all
	./Scripts/install.sh

package: all
	rm -rf "$(PACKAGE_SCRIPTS)"
	mkdir -p "$(PACKAGE_SCRIPTS)/Resources/build" \
		"$(PACKAGE_SCRIPTS)/Resources/Scripts/lib" \
		"$(PACKAGE_SCRIPTS)/Resources/LaunchAgents" "$(OUTPUT_DIR)"
	cp Package/Scripts/postinstall "$(PACKAGE_SCRIPTS)/postinstall"
	cp -R "$(PREFPANE_DIR)" "$(PACKAGE_SCRIPTS)/Resources/build/BadgePreferencePane.prefPane"
	cp "$(PREFERENCE_TOOL)" "$(PACKAGE_SCRIPTS)/Resources/build/BadgePreferenceTool"
	cp Scripts/hide-badge.sh Scripts/uninstall.sh "$(PACKAGE_SCRIPTS)/Resources/Scripts/"
	cp Scripts/lib/classify-updates.sh "$(PACKAGE_SCRIPTS)/Resources/Scripts/lib/"
	cp LaunchAgents/*.plist "$(PACKAGE_SCRIPTS)/Resources/LaunchAgents/"
	chmod 755 "$(PACKAGE_SCRIPTS)/postinstall"
	pkgbuild --nopayload --scripts "$(PACKAGE_SCRIPTS)" \
		--identifier com.kilinccagatay.TahoeUpdateBadgeBlocker \
		--version "$(VERSION)" --install-location / \
		"$(OUTPUT_DIR)/$(PACKAGE_NAME)"
	shasum -a 256 "$(OUTPUT_DIR)/$(PACKAGE_NAME)" > "$(OUTPUT_DIR)/$(PACKAGE_NAME).sha256"

test:
	./Tests/classify-updates.zsh

uninstall:
	./Scripts/uninstall.sh

clean:
	rm -rf "$(BUILD_DIR)"
