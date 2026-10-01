ifdef SIMULATOR
export TARGET = simulator:clang:latest:8.0
else
export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64 arm64e
endif

TWEAK_NAME = FPSIndicator

FPSIndicator_FILES = Tweak.x
FPSIndicator_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function -include Prefix.pch
FPSIndicator_CFLAGS += -I$(THEOS_PROJECT_DIR)/libcolorpicker
FPSIndicator_FRAMEWORKS = Foundation UIKit QuartzCore

FPSIndicator_FILES += libcolorpicker/libcolorpicker.mm

# Preference bundle is only useful on jailbroken devices and needs the AltList
# framework; it is opt-in so that plain injection builds work everywhere.
# Enable with: make FPS_WITH_PREFS=1
ifeq ($(FPS_WITH_PREFS),1)
SUBPROJECTS += fpsindicatorpref
endif

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
ifeq ($(FPS_WITH_PREFS),1)
include $(THEOS_MAKE_PATH)/aggregate.mk
endif

after-install::
	install.exec "killall -9 fatego" || true
	install.exec "killall -9 Preferences" || true
