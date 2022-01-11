
TARGET_TRIPLE = $(shell $(CC) -dumpmachine 2>/dev/null)

ifneq ($(findstring -mingw,$(TARGET_TRIPLE)),)
	TARGET_OS=Windows
else ifneq ($(findstring -darwin, $(TARGET_TRIPLE)),)
	TARGET_OS=Darwin
else ifneq ($(findstring -android,$(TARGET_TRIPLE)),)
	TARGET_OS=Android
else ifneq ($(findstring -linux,  $(TARGET_TRIPLE)),)
	TARGET_OS=Linux
else
	TARGET_OS=$(shell uname -s)
endif

all:
	@echo $(CC)
	@echo $(OS)
	@echo $(TARGET_TRIPLE)
	@echo $(TARGET_OS)
