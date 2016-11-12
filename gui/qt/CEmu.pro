# Warn if Qt isn't as updated as it should be
lessThan(QT_MAJOR_VERSION, 5) : error("You need at least Qt 5.6 to build CEmu!")
lessThan(QT_MINOR_VERSION, 6) : error("You need at least Qt 5.6 to build CEmu!")

# Warn if git submodules not downloaded
!exists("lua/lua/lua.h"): error("You have to run 'git submodule init' and 'git submodule update' first.")

# CEmu version
if (0) { # GitHub release/deployment build. Has to correspond to the git tag.
    DEFINES += CEMU_VERSION=\\\"1.0\\\"
} else { # Development build. Used in the about screen
    GIT_VERSION = $$system(git describe --abbrev=7 --dirty --always --tags)
    DEFINES += CEMU_VERSION=\\\"0.9dev_$$GIT_VERSION\\\"
}

# Continuous Integration (variable checked later)
CI = $$(CI)

# Code beautifying
DISTFILES += ../../.astylerc

# Linux desktop files
if (linux) {
    isEmpty(PREFIX) {
        PREFIX = /usr
    }
    target.path = $$PREFIX/bin
    desktop.target = desktop
    desktop.path = $$PREFIX/share/applications
    desktop.commands += xdg-desktop-menu install --novendor --mode system resources/linux/cemu.desktop &&
    desktop.commands += xdg-mime install --novendor --mode system resources/linux/cemu.xml &&
    desktop.commands += xdg-mime default cemu.desktop application/x-tice-rom &&
    desktop.commands += xdg-mime default cemu.desktop application/x-cemu-image &&
    desktop.commands += for length in 512 256 192 160 128 96 72 64 48 42 40 36 32 24 22 20 16; do xdg-icon-resource install --novendor --context apps --mode system --size \$\$length resources/icons/linux/cemu-\$\$\{length\}x\$\$length.png cemu; done
    desktop.uninstall += xdg-desktop-menu uninstall --novendor --mode system resources/linux/cemu.desktop &&
    desktop.uninstall += xdg-mime uninstall --novendor --mode system resources/linux/cemu.xml &&
    desktop.uninstall += for length in 512 256 192 160 128 96 72 64 48 42 40 36 32 24 22 20 16; do xdg-icon-resource uninstall --novendor --context apps --mode system --size \$\$length resources/icons/linux/cemu-\$\$\{length\}x\$\$length.png cemu; done
    INSTALLS += target desktop
}

QT += core gui widgets network

TARGET = CEmu
TEMPLATE = app

# Localization
TRANSLATIONS += i18n/fr_FR.ts i18n/es_ES.ts i18n/nl_NL.ts

# We use C++11, but Sol also uses C++14.
CONFIG += c++14 console

# Core options
DEFINES += DEBUG_SUPPORT

CONFIG(release, debug|release) {
    #This is a release build
    DEFINES += QT_NO_DEBUG_OUTPUT
} else {
    #This is a debug build
    GLOBAL_FLAGS += -g3
}

# TODO Lua: adjust options by platforms, see Makefile


# GCC/clang flags
if (!win32-msvc*) {
    GLOBAL_FLAGS    += -W -Wall -Wextra -Wunused-function -Werror=write-strings -Werror=redundant-decls -Werror=format -Werror=format-security -Werror=declaration-after-statement -Werror=implicit-function-declaration -Werror=date-time -Werror=missing-prototypes -Werror=return-type -Werror=pointer-arith -Winit-self
    GLOBAL_FLAGS    += -ffunction-sections -fdata-sections -fno-strict-overflow
    QMAKE_CFLAGS    += -std=gnu11
    QMAKE_CXXFLAGS  += -fno-exceptions -ftemplate-depth=1500
    isEmpty(CI) {
        # Only enable opts for non-CI release builds
        # -flto might cause an internal compiler error on GCC in some circumstances (with -g3?)... Comment it if needed.
        CONFIG(release, debug|release): GLOBAL_FLAGS += -O3 -flto
    }
        
    # You should run ./capture/get_libpng-apng.sh first!
    CONFIG += link_pkgconfig
    PKGCONFIG += libpng zlib
} else {
    # TODO: add equivalent flags
    # Example for -Werror=shadow: /weC4456 /weC4457 /weC4458 /weC4459
    #     Source: https://connect.microsoft.com/VisualStudio/feedback/details/1355600/
    QMAKE_CXXFLAGS  += /Wall
    
    # Note that libpng/zlib LIBS/INCLUDES should be specified in the envrionment.
    # We will use LIBPNG_APNG_LIB, ZLIB_LIB, and LIBPNG_APNG_INCLUDE.
    # The logic below accounts for both specifying in the real shell environment,
    # as well as directly on the command line (e.g. qmake VAR=1).
    isEmpty(LIBPNG_APNG_LIB) {
        LIBPNG_APNG_LIB = $$(LIBPNG_APNG_LIB)
        isEmpty(LIBPNG_APNG_LIB) {
            error("For MSVC builds, we require LIBPNG_APNG_LIB to point to the libpng-apng lib file to compile against. Please set this in your environment and try again.")
        }
    }
    isEmpty(ZLIB_LIB) {
        ZLIB_LIB = $$(ZLIB_LIB)
        isEmpty(ZLIB_LIB) {
            error("For MSVC builds, we require ZLIB_LIB to point to the zlib lib file to compile against. Please set this in your environment and try again.")
        }
    }
    isEmpty(LIBPNG_APNG_INCLUDE) {
        LIBPNG_APNG_INCLUDE = $$(LIBPNG_APNG_INCLUDE)
        isEmpty(LIBPNG_APNG_INCLUDE) {
            error("For MSVC builds, we require LIBPNG_APNG_INCLUDE to point to the libpng-apng include director to use for compiling. Please set this in your environment and try again.")
        }
    }
    
    LIBS += $$LIBPNG_APNG_LIB $$ZLIB_LIB
    INCLUDEPATH += $$LIBPNG_APNG_INCLUDE
}

if (macx|linux) {
    # Be more secure by default...
    GLOBAL_FLAGS    += -fPIE -Wstack-protector -fstack-protector-strong --param=ssp-buffer-size=1
    # Use ASAN on debug builds. Watch out about ODR crashes when built with -flto. detect_odr_violation=0 as an env var may help.
    CONFIG(debug, debug|release): GLOBAL_FLAGS += -fsanitize=address,bounds -fsanitize-undefined-trap-on-error -O0
}

macx:  QMAKE_LFLAGS += -Wl,-dead_strip
linux: QMAKE_LFLAGS += -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack -Wl,--gc-sections -pie

QMAKE_CFLAGS    += $$GLOBAL_FLAGS
QMAKE_CXXFLAGS  += $$GLOBAL_FLAGS
QMAKE_LFLAGS    += $$GLOBAL_FLAGS

macx: ICON = resources/icons/icon.icns

SOURCES +=  utils.cpp \
    main.cpp \
    mainwindow.cpp \
    romselection.cpp \
    lcdwidget.cpp \
    emuthread.cpp \
    datawidget.cpp \
    dockwidget.cpp \
    searchwidget.cpp \
    basiccodeviewerwindow.cpp \
    sendinghandler.cpp \
    debugger.cpp \
    hexeditor.cpp \
    settings.cpp \
    ipc.cpp \
    keyhistory.cpp \
    memoryvisualizer.cpp \
    luascripting.cpp \
    luaeditor.cpp \
    keypad/qtkeypadbridge.cpp \
    keypad/keymap.cpp \
    keypad/keypadwidget.cpp \
    keypad/rectkey.cpp \
    keypad/arrowkey.cpp \
    qhexedit/chunks.cpp \
    qhexedit/commands.cpp \
    qhexedit/qhexedit.cpp \
    tivarslib/utils_tivarslib.cpp \
    tivarslib/TypeHandlers/DummyHandler.cpp \
    tivarslib/TypeHandlers/TH_0x00.cpp \
    tivarslib/TypeHandlers/TH_0x01.cpp \
    tivarslib/TypeHandlers/TH_0x02.cpp \
    tivarslib/TypeHandlers/TH_0x05.cpp \
    tivarslib/TypeHandlers/TH_0x0C.cpp \
    tivarslib/TypeHandlers/TH_0x0D.cpp \
    tivarslib/TypeHandlers/TH_0x1B.cpp \
    tivarslib/TypeHandlers/TH_0x1C.cpp \
    tivarslib/TypeHandlers/TH_0x1D.cpp \
    tivarslib/TypeHandlers/TH_0x1E.cpp \
    tivarslib/TypeHandlers/TH_0x1F.cpp \
    tivarslib/TypeHandlers/TH_0x20.cpp \
    tivarslib/TypeHandlers/TH_0x21.cpp \
    ../../tests/autotester/autotester.cpp \
    lua/lua/lapi.c \
    lua/lua/lauxlib.c \
    lua/lua/lbaselib.c \
    lua/lua/lbitlib.c \
    lua/lua/lcode.c \
    lua/lua/lcorolib.c \
    lua/lua/lctype.c \
    lua/lua/ldblib.c \
    lua/lua/ldebug.c \
    lua/lua/ldo.c \
    lua/lua/ldump.c \
    lua/lua/lfunc.c \
    lua/lua/lgc.c \
    lua/lua/linit.c \
    lua/lua/liolib.c \
    lua/lua/llex.c \
    lua/lua/lmathlib.c \
    lua/lua/lmem.c \
    lua/lua/loadlib.c \
    lua/lua/lobject.c \
    lua/lua/lopcodes.c \
    lua/lua/loslib.c \
    lua/lua/lparser.c \
    lua/lua/lstate.c \
    lua/lua/lstring.c \
    lua/lua/lstrlib.c \
    lua/lua/ltable.c \
    lua/lua/ltablib.c \
    lua/lua/ltm.c \
    lua/lua/lundump.c \
    lua/lua/lutf8lib.c \
    lua/lua/lvm.c \
    lua/lua/lzio.c \
    ../../core/asic.c \
    ../../core/cpu.c \
    ../../core/keypad.c \
    ../../core/lcd.c \
    ../../core/registers.c \
    ../../core/port.c \
    ../../core/interrupt.c \
    ../../core/flash.c \
    ../../core/misc.c \
    ../../core/schedule.c \
    ../../core/timers.c \
    ../../core/usb.c \
    ../../core/sha256.c \
    ../../core/realclock.c \
    ../../core/backlight.c \
    ../../core/cert.c \
    ../../core/control.c \
    ../../core/mem.c \
    ../../core/link.c \
    ../../core/vat.c \
    ../../core/emu.c \
    ../../core/extras.c \
    ../../core/debug/disasm.cpp \
    ../../core/debug/stepping.cpp \
    ../../core/debug/debug.cpp \
    ../../core/spi.c \
    capture/animated-png.c \
    memoryvisualizerwidget.cpp

linux|macx: SOURCES += ../../core/os/os-linux.c
win32: SOURCES += ../../core/os/os-win32.c win32-console.cpp
win32: LIBS += -lpsapi

HEADERS  +=  utils.h \
    mainwindow.h \
    romselection.h \
    lcdwidget.h \
    emuthread.h \
    datawidget.h \
    dockwidget.h \
    searchwidget.h \
    cemuopts.h \
    sendinghandler.h \
    debugger.h \
    ipc.h \
    keyhistory.h \
    memoryvisualizer.h \
    basiccodeviewerwindow.h \
    keypad/qtkeypadbridge.h \
    keypad/keymap.h \
    keypad/keypadwidget.h \
    keypad/key.h \
    keypad/keyconfig.h \
    keypad/rectkey.h \
    keypad/graphkey.h \
    keypad/secondkey.h \
    keypad/alphakey.h \
    keypad/otherkey.h \
    keypad/numkey.h \
    keypad/operkey.h \
    keypad/arrowkey.h \
    keypad/keycode.h \
    qhexedit/chunks.h \
    qhexedit/commands.h \
    qhexedit/qhexedit.h \
    tivarslib/autoloader.h \
    tivarslib/utils_tivarslib.h \
    tivarslib/TypeHandlers/TypeHandlerFuncGetter.h \
    tivarslib/TypeHandlers/TypeHandlers.h \
    ../../tests/autotester/autotester.h \
    lua/lua/lapi.h \
    lua/lua/lauxlib.h \
    lua/lua/lcode.h \
    lua/lua/lctype.h \
    lua/lua/ldebug.h \
    lua/lua/ldo.h \
    lua/lua/lfunc.h \
    lua/lua/lgc.h \
    lua/lua/llex.h \
    lua/lua/llimits.h \
    lua/lua/lmem.h \
    lua/lua/lobject.h \
    lua/lua/lopcodes.h \
    lua/lua/lparser.h \
    lua/lua/lprefix.h \
    lua/lua/lstate.h \
    lua/lua/lstring.h \
    lua/lua/ltable.h \
    lua/lua/ltm.h \
    lua/lua/lua.h \
    lua/lua/luaconf.h \
    lua/lua/lualib.h \
    lua/lua/lundump.h \
    lua/lua/lvm.h \
    lua/lua/lzio.h \
    lua/sol.hpp \
    ../../core/asic.h \
    ../../core/cpu.h \
    ../../core/defines.h \
    ../../core/keypad.h \
    ../../core/lcd.h \
    ../../core/registers.h \
    ../../core/tidevices.h \
    ../../core/port.h \
    ../../core/interrupt.h \
    ../../core/emu.h \
    ../../core/flash.h \
    ../../core/misc.h \
    ../../core/schedule.h \
    ../../core/timers.h \
    ../../core/usb.h \
    ../../core/sha256.h \
    ../../core/realclock.h \
    ../../core/backlight.h \
    ../../core/cert.h \
    ../../core/control.h \
    ../../core/mem.h \
    ../../core/link.h \
    ../../core/vat.h \
    ../../core/extras.h \
    ../../core/os/os.h \
    ../../core/debug/debug.h \
    ../../core/debug/disasm.h \
    ../../core/debug/stepping.h \
    ../../core/spi.h \
    capture/animated-png.h \
    memoryvisualizerwidget.h

FORMS    += mainwindow.ui \
    romselection.ui \
    searchwidget.ui \
    basiccodeviewerwindow.ui \
    keyhistory.ui \
    memoryvisualizer.ui

RESOURCES += \
    resources.qrc

RC_ICONS += resources\icons\icon.ico
