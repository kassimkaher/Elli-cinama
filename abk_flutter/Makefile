# ABK Player — build & run
# Usage: `make <target>`.  `make help` lists everything.
#
# Distribution builds (apk/aab/ipa/macos/windows) are PRODUCTION: no QA autofill.
# Run targets include qa-defines.json (if present) so the QA autofill card shows.

FLUTTER      ?= flutter
DEVICE       ?=                       # e.g. DEVICE=00008120-00127596216A601E  (or bf5c6761 / macos)
EXPORT_METHOD ?= development          # ipa: development | ad-hoc | app-store | enterprise
ANDROID_HOME ?= $(HOME)/Library/Android/sdk
QA_FILE      := qa-defines.json
DIST         := build/dist

# --dart-define-from-file only when the local QA file exists (dev/QA convenience).
QA_FLAG      := $(if $(wildcard $(QA_FILE)),--dart-define-from-file=$(QA_FILE),)
DEVICE_FLAG  := $(if $(DEVICE),-d $(DEVICE),)

.DEFAULT_GOAL := help
.PHONY: help pub clean gen icons analyze test doctor \
        apk apk-split aab tv-apk tv-aab tv-run ios ipa macos windows-enable windows \
        run run-release run-debug release-all dist

## ---- meta -----------------------------------------------------------------
help:  ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

pub:  ## flutter pub get
	$(FLUTTER) pub get

clean:  ## flutter clean (removes build/) then pub get
	$(FLUTTER) clean && $(FLUTTER) pub get

icons:  ## Regenerate launcher/app icons from assets/brand
	dart run flutter_launcher_icons

gen: icons  ## Alias for icons

analyze:  ## Static analysis
	$(FLUTTER) analyze

test:  ## Unit + widget tests
	$(FLUTTER) test

doctor:  ## flutter doctor -v
	$(FLUTTER) doctor -v

## ---- Android --------------------------------------------------------------
apk:  ## Release APK (universal)         -> build/app/outputs/flutter-apk/app-release.apk
	$(FLUTTER) build apk --release

apk-split:  ## Release APKs split per ABI (smaller)
	$(FLUTTER) build apk --release --split-per-abi

aab:  ## Release App Bundle (Play Store) -> build/app/outputs/bundle/release/app-release.aab
	$(FLUTTER) build appbundle --release

tv-apk:  ## Release APK for Android TV / Google TV (same APK; verifies leanback entry)
	$(FLUTTER) build apk --release
	@echo "== Android TV manifest check =="
	@AAPT="$$(ls -d $(ANDROID_HOME)/build-tools/*/ 2>/dev/null | sort -V | tail -1)aapt2"; \
	 APK=build/app/outputs/flutter-apk/app-release.apk; \
	 if [ -x "$$AAPT" ]; then \
	   "$$AAPT" dump badging "$$APK" 2>/dev/null | grep -iE "leanback-launchable-activity|banner=|uses-feature-not-required.*(leanback|touchscreen)" \
	     && echo "TV-ready APK -> $$APK" || echo "WARNING: leanback entry not found"; \
	 else echo "(aapt2 not found — built $$APK, skipped verify)"; fi

tv-aab:  ## Release App Bundle for Android TV (Play Store TV track)
	$(FLUTTER) build appbundle --release
	@echo "TV AAB -> build/app/outputs/bundle/release/app-release.aab"

tv-run:  ## Run on a TV emulator/device, forcing TV mode (DEVICE=emulator-5554)
	$(FLUTTER) run --release $(DEVICE_FLAG) --dart-define=ABK_FORCE_TV=true $(QA_FLAG)

## ---- iOS (macOS host only) ------------------------------------------------
ios:  ## Release Runner.app (no packaging) -> build/ios/iphoneos/Runner.app
	$(FLUTTER) build ios --release

ipa:  ## Release IPA (EXPORT_METHOD=$(EXPORT_METHOD)) -> build/ios/ipa/*.ipa
	$(FLUTTER) build ipa --release --export-method=$(EXPORT_METHOD)

## ---- macOS (macOS host only) ----------------------------------------------
macos:  ## Release .app -> build/macos/Build/Products/Release/abk_player.app
	$(FLUTTER) build macos --release

## ---- Windows (Windows host only) ------------------------------------------
windows-enable:  ## One-time: enable + scaffold windows/ runner
	$(FLUTTER) config --enable-windows-desktop
	$(FLUTTER) create --platforms=windows .

windows:  ## Release Windows build -> build/windows/x64/runner/Release/
	$(FLUTTER) build windows --release

## ---- Run ------------------------------------------------------------------
run: run-release  ## Alias for run-release

run-release:  ## Run RELEASE on DEVICE (QA card shown if qa-defines.json exists)
	$(FLUTTER) run --release $(DEVICE_FLAG) $(QA_FLAG)

run-debug:  ## Run DEBUG on DEVICE (QA card shown if qa-defines.json exists)
	$(FLUTTER) run --debug $(DEVICE_FLAG) $(QA_FLAG)

## ---- Bundles --------------------------------------------------------------
release-all: apk aab macos  ## Build everything buildable on this macOS host (apk + aab + macOS)
	@echo "Done. (ipa: run 'make ipa'; windows: run 'make windows' on a Windows host)"

dist:  ## Copy built artifacts into $(DIST)/ with clear names
	@mkdir -p $(DIST)
	@[ -f build/app/outputs/flutter-apk/app-release.apk ] && cp -f build/app/outputs/flutter-apk/app-release.apk $(DIST)/ABK-Player.apk && echo "  APK  -> $(DIST)/ABK-Player.apk" || true
	@[ -f build/app/outputs/bundle/release/app-release.aab ] && cp -f build/app/outputs/bundle/release/app-release.aab $(DIST)/ABK-Player.aab && echo "  AAB  -> $(DIST)/ABK-Player.aab" || true
	@ls build/ios/ipa/*.ipa >/dev/null 2>&1 && cp -f build/ios/ipa/*.ipa $(DIST)/ABK-Player.ipa && echo "  IPA  -> $(DIST)/ABK-Player.ipa" || true
	@[ -d build/macos/Build/Products/Release/abk_player.app ] && /usr/bin/ditto -c -k --sequesterRsrc --keepParent build/macos/Build/Products/Release/abk_player.app $(DIST)/ABK-Player-macOS.zip && echo "  macOS-> $(DIST)/ABK-Player-macOS.zip" || true
	@ls -d build/windows/x64/runner/Release >/dev/null 2>&1 && (cd build/windows/x64/runner && zip -qr "$(CURDIR)/$(DIST)/ABK-Player-Windows.zip" Release) && echo "  Win  -> $(DIST)/ABK-Player-Windows.zip" || true
	@echo "Collected into $(DIST)/"
