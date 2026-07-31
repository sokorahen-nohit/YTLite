ARCHS = arm64
TARGET := iphone:clang:16.5:13.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BluetoothBackgroundGuard

BluetoothBackgroundGuard_FILES = Tweak.x
BluetoothBackgroundGuard_FRAMEWORKS = UIKit Foundation AVFoundation
BluetoothBackgroundGuard_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
