# Parameter explanations:
#   CC - compiler used by the Makefile. Can be whatever you desire.
#
#   PLATFORM - sets the platform target to compile for. Current values: WIN32_GNU,
# WIN32_MSVC, OS_X, LINUX, WASM_WASI, WASM_EMCC, 3DS, DEFAULT. Selecting 'DEFAULT'
# makes the Makefile automatically guess which platform to target.
#
# 	MODE - sets the release mode to compile for. Current values: FAST, MODE,
# RELEASE. 'FAST' disables all flags and enables ones requires for fast compilation.
# 'MODE' turns on all warnings as well as flags to help with MODEging/finding
# problematic code. 'RELEASE' turns on all optimisations as well as warnings.
#
# 	LANGUAGE - selects which programming language to target. Currently C and C++
# are the only valid options.

CC        = arm-none-eabi-gcc
PLATFORM  = 3DS
MODE      = FAST
LANGUAGE  = C

# Building options:
#	NAME   - the executable name.
#	SRC    - source file to target.
#	OUTPUT - the directory where all of the output goes to.
NAME   = basic
SRC    = examples/embedded/portableGL/pgl.c
OUTPUT = build


ifeq ($(PLATFORM),DEFAULT)
	ifneq (,$(filter $(CC),mingw32-gcc x86_64-w64-mingw32-g++ w64gcc w32gcc))
		PLATFORM = WIN32_GNU
	else ifneq (,$(filter $(CC),cl))
		PLATFORM = WIN32_MSVC
	else ifneq (,$(filter $(CC), wasi))
		PLATFORM = WASM_WASI
	else ifneq (,$(filter $(CC), emcc))
		PLATFORM = WASM_EMCC
	else
		DETECTED_OS := $(shell uname 2>/dev/null || echo Unknown)

		ifeq ($(DETECTED_OS),Darwin)
			PLATFORM = OS_X
		else ifeq ($(DETECTED_OS),Linux)
			PLATFORM = LINUX
		else
			$(error Unsupported platform. Please refer to the Makefile for supported platofmrs.)
		endif
	endif
endif


ifeq ($(LANGUAGE),C)
	GNU_FLAGS = -std=c99 -x c -Wvla
else ifeq ($(LANGUAGE),CPP)
	GNU_FLAGS = -std=c++11 -x c++ -fno-exceptions
endif


ifeq ($(MODE),FAST)
	GNU_FLAGS += -O0 -flto

else
	GNU_FLAGS += \
		-Wall -Wextra -Wpedantic \
		-Wconversion -Wsign-conversion -Wdouble-promotion \
		\
		-Wpointer-arith \
		\
		-Wcast-align \
		\
		\
		-Wmissing-prototypes -Wstrict-prototypes -Wold-style-definition \
		\
		-Wswitch-enum -Wnested-externs \
		\
		-Werror=format-security -Wformat=2 -Wformat-signedness \
		\
		-Winit-self -Wshadow -Wredundant-decls \
		\
		-Wmissing-noreturn \
		\
		-fwrapv -fstrict-aliasing \
		-fstrict-flex-arrays=3 -fno-omit-frame-pointer

	ifneq (,$(filter $(CC),gcc g++))
		GNU_FLAGS += -Wcast-align=strict -Wlogical-op
	endif

	ifeq ($(MODE),DEBUG)
		GNU_FLAGS += \
			-fstack-clash-protection \
			-fstack-protector-strong \
			-ftrivial-auto-var-init=pattern

		ifneq ($(PLATFORM),3DS)
			GNU_FLAGS += -fsanitize=undefined -fsanitize=address
		endif
	else ifeq ($(MODE),RELEASE)
		GNU_FLAGS += \
			-O3 \
			-D SI_RELEASE_MODE \
			-fno-delete-null-pointer-checks \
			-fno-strict-aliasing \
			-ftrivial-auto-var-init=zero \
			-flto
	endif
endif

GNU_INCLUDES = -I"." -I"include"


ifeq ($(PLATFORM),DEFAULT)
	ifneq (,$(filter $(CC),mingw32-gcc x86_64-w64-mingw32-g++ w64gcc w32gcc))
		PLATFORM = WIN32_GNU
	else ifneq (,$(filter $(CC),cl))
		PLATFORM = WIN32_MSVC
	else ifneq (,$(filter $(CC), wasi))
		PLATFORM = WASM_WASI
	else ifneq (,$(filter $(CC), emcc))
		PLATFORM = WASM_EMCC
	else
		DETECTED_OS := $(shell uname 2>/dev/null || echo Unknown)

		ifeq ($(DETECTED_OS),Darwin)
			PLATFORM = OS_X
		else ifeq ($(DETECTED_OS),Linux)
			PLATFORM = LINUX
		else
			$(error Unsupported platform. Please refer to the Makefile for supported platofmrs.)
		endif
	endif
endif

ifeq ($(PLATFORM),WIN32_GNU)
	FLAGS = $(GNU_FLAGS)
	INCLUDES = $(GNU_INCLUDES)

	LIBS = -lkernel32 -lole32 -lopengl32
	EXE_OUT = .exe

else ifeq ($(PLATFORM),WIN32_MSVC)
	FLAGS = -nologo -std:c11 -Wall -wd4668 -wd4820 -wd5045
	INCLUDES = -I"." -I"include"
	ifeq ($(MODE),0)
		FLAGS += -O2 -wd4711 -D SI_RELEASE_MODE
	endif

	LIBS =
	EXE_OUT = .exe

else ifeq ($(PLATFORM),OS_X)
	FLAGS = $(GNU_FLAGS)
	INCLUDES = $(GNU_INCLUDES)

	LIBS    = -lpthread -ldl
	EXE_OUT =

else ifeq ($(PLATFORM),LINUX)
	FLAGS = $(GNU_FLAGS)
	INCLUDES = $(GNU_INCLUDES)

	LIBS    = -lpthread -ldl -lX11 -lXrandr -lGL
	EXE_OUT =

else ifeq ($(PLATFORM),WASM_WASI)
	FLAGS = --target=wasm32-wasi $(GNU_FLAGS)
	INCLUDES = $(GNU_INCLUDES)

	LIBS =
	EXE_OUT = .wasm

else ifeq ($(PLATFORM),WASM_EMCC)
	FLAGS = --target=wasm32-unknown-emscripten -s WASM=1 -s ASYNCIFY -s PTHREAD_POOL_SIZE=4 \
		$(GNU_FLAGS)
	INCLUDES = $(GNU_INCLUDES)

	LIBS    = -pthread
	EXE_OUT = .html

else ifeq ($(PLATFORM),3DS)
	ifeq ($(strip $(DEVKITPRO)),)
		$(error DEVKITPRO must be set in your environment: export DEVKITPRO=<path to devkitpro>)
	endif
	ifeq ($(strip $(DEVKITARM)),)
		$(error DEVKITARM must be set in your environment: export DEVKITARM=<path to devkitARM>)
	endif

	DESCRIPTION = RGFW examples for the Nintendo 3DS
	AUTHOR      = EimaMei
	ICON        = ../../res/default_icon.png

	FLAGS = $(GNU_FLAGS) -specs=3dsx.specs -D __3DS__ -mword-relocations -ffunction-sections -march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft
	INCLUDES = $(GNU_INCLUDES) -I"$(CURDIR)" -I"$(DEVKITPRO)/libctru/include" -I"$(DEVKITARM)/include"

	LIBS = -L$(DEVKITPRO)/libctru/lib/ -lcitro3d -lcitro2d -lctru -lm
	EXE_OUT = .3dsx

	export PATH := $(DEVKITPRO)/tools/bin:$(DEVKITARM)/bin:$(DEVKITPRO)/portlibs/3ds/bin:$(PATH)

else
	$(error Unsupported platform. Please refer to the Makefile for supported platofmrs.)

endif

EXE = $(OUTPUT)/$(NAME)$(EXE_OUT)


# 'make'
all: $(OUTPUT) $(EXE) run

# Run the executable.
run: $(EXE)
	./$(EXE)

# Clean the 'build' folder.
clean:
	rm -rf $(OUTPUT)/*

$(EXE): $(SRC) RGFW_embedded.h Makefile examples/*
ifeq ($(PLATFORM),3DS)
	$(CC) $(FLAGS) $(INCLUDES) $(SRC) $(LIBS) -o "$(OUTPUT)/$(NAME).elf"

    ifeq ($(EXE_OUT),.3dsx)
	smdhtool --create "$(NAME)" "$(DESCRIPTION)" "$(AUTHOR)" "$(ICON)" "$(OUTPUT)/$(NAME).smdh"
	3dsxtool "$(OUTPUT)/$(NAME).elf" "$(OUTPUT)/$(NAME).3dsx" --smdh="$(OUTPUT)/$(NAME).smdh"
    endif

else
	$(CC) $(FLAGS) $(SRC) $(INCLUDES) $(LIBS) $(CC_OUT)"$@"
endif

# If 'build' doesn't exist, create it
$(OUTPUT):
	mkdir $(OUTPUT)
