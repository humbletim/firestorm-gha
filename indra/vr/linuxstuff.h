// linux-specific VR glue code -- humbletim @ 2020.06.30
#pragma once

// emulate WIN32 ::GetSystemMetrics and ::GetKeyState on linux
#ifdef __linux__

namespace vr {
  bool toggleFullscreen() { LL_WARNS() << "TODO: Linux Fullscreen support" << LL_ENDL; return false; }
}

	#include <X11/Xlib.h>
	#define SM_CXSCREEN "SM_CXSCREEN"
	#define SM_CYSCREEN "SM_CYSCREEN"

	Display* _display = XOpenDisplay(NULL);

	inline int GetSystemMetrics(const std::string& name) {
		Screen* screen = _display ? DefaultScreenOfDisplay(_display) : nullptr;
		if (name == SM_CXSCREEN && screen) return WidthOfScreen(screen);
		else if (name == SM_CYSCREEN && screen) return HeightOfScreen(screen);
		return 512;
	}

	#define Status int // wtf is defining Status somewhere ???
	#include <X11/XKBlib.h>

	inline bool _linux_iscapslocked() {
		unsigned n = 0;
		if (_display) {
			XkbGetIndicatorState(_display, XkbUseCoreKbd, &n);
		}
		return n & 1;
	}

	#define VK_CAPITAL "VK_CAPITAL"
	int GetKeyState(const std::string& name) {
		if (name == "VK_CAPITAL" && _linux_iscapslocked()) return 0x0001;
		return 0;
	}

#endif // linux

