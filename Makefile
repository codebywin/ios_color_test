THEOS_PACKAGE_SCHEME ?= roothide
TARGET := iphone:clang:15.6:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = VCAMColorTest
VCAMColorTest_FILES = main.m
VCAMColorTest_CFLAGS = -fobjc-arc
VCAMColorTest_FRAMEWORKS = UIKit QuartzCore AVFoundation
VCAMColorTest_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
