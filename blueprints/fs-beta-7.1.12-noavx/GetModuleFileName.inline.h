// intercept Win32 GetModuleFileName and substitute env EXEROOT for the path.
// note: this allows running the main .exe "out of tree" using a conventional
// installation as a backdrop for supporting .dll's, .xml resources, etc.
// --humbletim 2024.12.01
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#pragma comment(lib, "Shlwapi.lib")

extern "C" __declspec(dllimport) DWORD GetModuleFileNameW( HMODULE hModule, LPWSTR lpFilename, DWORD nSize );
extern "C" __declspec(dllimport) BOOL PathAppendW( LPWSTR pszPath, LPCWSTR pszMore);
extern "C" __declspec(dllimport) LPCWSTR PathFindFileNameW( LPCWSTR pszPath );
extern "C" __declspec(dllimport) DWORD GetEnvironmentVariableW(LPCWSTR lpName, LPWSTR lpBuffer, DWORD nSize);

DWORD MyGetModuleFileNameW(HMODULE hModule, LPWSTR lpFilename, DWORD nSize) {
  DWORD dwResult = GetModuleFileNameW(hModule, lpFilename, nSize); 
  if (dwResult == 0) return dwResult; 
  WCHAR* lpFileNameOnly = lpFilename;
  if (auto bs = wcsrchr(lpFilename, '\\')) lpFileNameOnly = bs+1;
  else if (auto bs = wcsrchr(lpFilename, '/')) lpFileNameOnly = bs+1;
  WCHAR szAppDataPath[MAX_PATH];
  dwResult = GetEnvironmentVariableW(L"EXEROOT", szAppDataPath, MAX_PATH);
  if (dwResult == 0) return dwResult;
  DWORD dwRequiredSize = dwResult + (DWORD)wcslen(lpFileNameOnly) + 2; // +1 for potential dir separator and +1 for null terminator
  if ((DWORD) wcslen(szAppDataPath) < nSize) {
    PathAppendW(szAppDataPath, lpFileNameOnly);
    wcscpy_s(lpFilename, nSize, szAppDataPath);
    return (DWORD)wcslen(lpFilename); 
  }
  return dwResult;
}

#undef GetModuleFileName
typedef DWORD (*MyFunctionType)(HMODULE hModule, LPWSTR   lpFilename, DWORD nSize);
static MyFunctionType GetModuleFileName = MyGetModuleFileNameW; 
