// win32-specific VR glue code -- humbletim @ 2020.06.30
#pragma once

#ifdef _WIN32
EXTERN_C IMAGE_DOS_HEADER __ImageBase;
namespace vr {

namespace win32 {
  // workaround to get main app window native handle
  struct _workaround : public LLWindowWin32 {
  public:
    static HWND _gethwnd(LLWindowWin32* other) {
      return other ? reinterpret_cast<_workaround*>(other)->mWindowHandle : 0;
    }
  };
  HWND _getNativeAppWindow() {
    return _workaround::_gethwnd(dynamic_cast<LLWindowWin32*>(gViewerWindow->getWindow()));
  }
  LLRect _getPrimaryMonitorSize(HWND hwnd = _getNativeAppWindow()) {
    MONITORINFO mi = { sizeof(mi) };
    ::GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY), &mi);
    return { mi.rcMonitor.left, -mi.rcMonitor.top, mi.rcMonitor.right, -mi.rcMonitor.bottom };
  }
  LLRect _getPrimaryWorkareaSize(HWND hwnd = _getNativeAppWindow()) {
    MONITORINFO mi = { sizeof(mi) };
    mi.cbSize = sizeof(mi);
    ::GetMonitorInfo(::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &mi);
    return { mi.rcWork.left, -mi.rcWork.top, mi.rcWork.right, -mi.rcWork.bottom };
  }
    // main screen native resolution
    int __cdecl WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
      static HBRUSH brush = CreateSolidBrush(RGB(0, 0, 0));
      switch (uMsg) {
      // case WNC_NCCREATE: return true;
      case WM_PAINT: {
          PAINTSTRUCT ps;
          HDC hdc = BeginPaint(hwnd, &ps);
          FillRect(hdc, &ps.rcPaint, brush);
          EndPaint(hwnd, &ps);
          return 0;
          break;
      }
      case WM_CLOSE: {
        PostMessage(_getNativeAppWindow(), WM_CLOSE, 0, 0);
        return 0;
        break;
      }
      }
      return DefWindowProc(hwnd, uMsg, wParam, lParam);
    }
    // create a placeholder "backdrop" that fills entire screen
    HWND _createNativeBackdropWindow() {
      const wchar_t CLASS_NAME[]  = L"Backdrop Window Class";
      WNDCLASSEX wc = { };
      memset( &wc, 0, sizeof( wc ) );
      wc.cbSize = sizeof( wc );
      wc.lpfnWndProc   = (WNDPROC)WindowProc;
      wc.hInstance     = ((HINSTANCE)&__ImageBase);
      wc.lpszClassName = CLASS_NAME;
      if (!RegisterClassEx(&wc)) {
          LL_WARNS("ViewerVR") << "could not RegisterClassEx; err=" << GetLastError() << LL_ENDL;
      }
      auto rect = _getPrimaryMonitorSize();
      LL_WARNS("ViewerVR") << wc.hInstance << " backdrop: " << "[" << rect.getWidth() << "x" << rect.getHeight() << "] " << rect.mLeft << "," << rect.mTop << LL_ENDL;
      auto hwnd = ::CreateWindowEx((DWORD)0, CLASS_NAME, L"backdrop", (DWORD)0, 0, 0, rect.getWidth(), rect.getHeight(), (HWND)0, (HMENU)0, wc.hInstance, nullptr);
      if (!hwnd) {
        LL_WARNS("ViewerVR") << "could not CreateWindowEx; err=" << GetLastError() << LL_ENDL;
      }
      return hwnd;
    }
  }//ns win32

    bool toggleFullscreen() {
      static HWND backdrop = 0;
      auto app = win32::_getNativeAppWindow();
      if (!backdrop) {
        backdrop = win32::_createNativeBackdropWindow();
        LL_WARNS("ViewerVR") << "going fullscreen: " << backdrop << LL_ENDL;
        ::SetWindowLong(backdrop, GWL_STYLE, ::GetWindowLong(app, GWL_STYLE) & ~WS_OVERLAPPEDWINDOW);
        ::SetWindowPos(backdrop, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
        ::SetWindowLong(app, GWL_STYLE, ::GetWindowLong(app, GWL_STYLE) & ~WS_OVERLAPPEDWINDOW);
        ::SetParent(app, backdrop);
        RECT rc;
        ::GetWindowRect(app, &rc);
        int width = llclamp<int>(rc.right - rc.left, 512, 4096);
        int height = llclamp<int>(rc.bottom - rc.top, 512, 4096);
        LL_WARNS("ViewerVR") << llformat("app: [%dx%d] @ %d,%d", width, height, 0, 0) << LL_ENDL;
        gViewerWindow->getWindow()->setPosition({0,0});
        ::SetWindowPos(app, HWND_TOP, 0, 0, width, height, SWP_NOMOVE | SWP_FRAMECHANGED);
        return true;
      } else {
        LL_WARNS("ViewerVR") << "going non-fullscreen: " << backdrop << LL_ENDL;
        RECT rc;
        ::GetWindowRect(app, &rc);
        int width = llclamp<int>(rc.right - rc.left, 512, 4096);
        int height = llclamp<int>(rc.bottom - rc.top, 512, 4096);
        LL_WARNS("ViewerVR") << llformat("//app: [%dx%d] @ %d,%d", width, height, 0, 0) << LL_ENDL;
        ::SetParent(app, 0L);
        ::SetWindowLong(app, GWL_STYLE, ::GetWindowLong(app, GWL_STYLE) | WS_OVERLAPPEDWINDOW);
        ::SetWindowPos(app, HWND_NOTOPMOST, 0, 0, width, height, SWP_FRAMECHANGED);
        ::DestroyWindow(backdrop);
        backdrop = 0;
        return false;
      }
    }
} //ns vr
#endif
