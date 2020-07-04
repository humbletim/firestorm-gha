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

namespace vr {
	LLRect _getPrimaryWorkareaSize() {
		LLRect rect;
		unsigned char *prop_return = nullptr;
		int32_t *return_words;
		Atom property, actual_type_return;
		int actual_format_return;
		unsigned long bytes_after_return, nitems_return;

		auto result = XGetWindowProperty(
			_display, DefaultRootWindow(_display),
			XInternAtom(_display, "_NET_WORKAREA", False), 
			0, 32 * 4,
			False,	/* delete */
			AnyPropertyType,	/* req_type */
			&actual_type_return, &actual_format_return,
			&nitems_return, &bytes_after_return,
			&prop_return
		);
		if (prop_return) {
			return_words = (int32_t *) prop_return;
			rect = { return_words[0], return_words[1], return_words[2]+return_words[0], -(return_words[3]+return_words[1]) };
			XFree(prop_return);
		}
		return rect;
	}
}//ns

#endif // linux

