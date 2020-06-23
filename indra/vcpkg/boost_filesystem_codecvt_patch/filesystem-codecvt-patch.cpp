// fix missing entries in boost::filesystem
// based on the original boost source (which for whatever reason overlooked these)
// TODO: confirm and submit a patch to corresponding boostorg/boost filesystem project

// #define BOOST_NO_INTRINSIC_WCHAR_T
// #define BOOST_NO_CWCHAR
//#include "linden_common.h"
// #define WIN32_LEAN_AND_MEAN
// #include <windows.h>
// #undef WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <codecvt>
#define convert asdf
// #include <boost/config.hpp>
// #include <boost/filesystem/path.hpp>
// #include <boost/filesystem/path_traits.hpp>
#undef convert
#include <locale>
namespace boost {
namespace filesystem {
namespace path_traits {
namespace {
    std::locale default_locale() {
    # if defined(BOOST_WINDOWS_API)
          class windows_file_codecvt : public std::codecvt< wchar_t, char, std::mbstate_t > {
            public:
                explicit windows_file_codecvt(std::size_t refs = 0) : std::codecvt<wchar_t, char, std::mbstate_t>(refs) {}
            protected:
                virtual bool do_always_noconv() const throw() { return false; }
                virtual int do_encoding() const throw() { return 0; }
                virtual std::codecvt_base::result do_in(std::mbstate_t& state, const char* from, const char* from_end, const char*& from_next, wchar_t* to, wchar_t* to_end, wchar_t*& to_next) const {
                   UINT codepage = AreFileApisANSI() ? CP_ACP : CP_OEMCP;
                   int count;
                   if ((count = ::MultiByteToWideChar(codepage, MB_PRECOMPOSED, from,
                     static_cast<int>(from_end - from), to, static_cast<int>(to_end - to))) == 0) {
                     return error;  // conversion failed
                   }
                   from_next = from_end;
                   to_next = to + count;
                   *to_next = L'\0';
                   return ok;
              }
              virtual std::codecvt_base::result do_out(std::mbstate_t & state, const wchar_t* from, const wchar_t* from_end, const wchar_t*& from_next, char* to, char* to_end, char*& to_next) const {
                  UINT codepage = AreFileApisANSI() ? CP_ACP : CP_OEMCP;
                  int count;
                  if ((count = ::WideCharToMultiByte(codepage, WC_NO_BEST_FIT_CHARS, from,
                    static_cast<int>(from_end - from), to, static_cast<int>(to_end - to), 0, 0)) == 0) {
                    return error;  // conversion failed
                  }
                  from_next = from_end;
                  to_next = to + count;
                  *to_next = '\0';
                  return ok;
              }
              virtual std::codecvt_base::result do_unshift(std::mbstate_t&, char* /*from*/, char* /*to*/, char* & /*next*/) const  { return ok; }
              virtual int do_length(std::mbstate_t&, const char* /*from*/, const char* /*from_end*/, std::size_t /*max*/) const  { return 0; }
              virtual int do_max_length() const throw () { return 0; }
          };
          std::locale global_loc = std::locale();
          return std::locale(global_loc, new windows_file_codecvt);
    # elif defined(macintosh) || defined(__APPLE__) || defined(__APPLE_CC__) \
            || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__HAIKU__)
          std::locale global_loc = std::locale();
          return std::locale(global_loc, new boost::filesystem::detail::utf8_codecvt_facet);
    # else  // Other POSIX
          return std::locale("");
    # endif
    } // default_locale
             

    std::string w2s(const std::wstring &var) {
        static auto loc(default_locale());
       auto &facet = std::use_facet<std::codecvt<wchar_t, char, std::mbstate_t>>(loc);
       return std::wstring_convert<std::remove_reference<decltype(facet)>::type, wchar_t>(&facet).to_bytes(var);
    }

    std::wstring s2w(const std::string &var) {
        static auto loc(default_locale());
       auto &facet = std::use_facet<std::codecvt<wchar_t, char, std::mbstate_t>>(loc);
       return std::wstring_convert<std::remove_reference<decltype(facet)>::type, wchar_t>(&facet).from_bytes(var);
    }
}
typedef std::codecvt<unsigned short, char, std::mbstate_t> codecvt_type;

     __declspec(dllexport) void convert(const char* from, const char* from_end, std::wstring & to, const codecvt_type&t) {
       // BOOST_ASSERT(from);
  	   // BOOST_ASSERT(from_end);
       to.append(s2w({ from, from_end }));
       //to.append(from, from_end);
     }
     __declspec(dllexport) void convert(const unsigned short* from, const unsigned short* from_end, std::string & to, const codecvt_type&t) {
       // BOOST_ASSERT(from);
  	   // BOOST_ASSERT(from_end);
       //std::string ws(s.size());
       //ws.resize(mbstowcs(&ws[0], s.c_str(), s.size());
       to.append(w2s({ from, from_end }));
       //to.append(from, from_end);
     }
} //path_traits
} // filesystem
} // boost

#include <boost/filesystem/path.hpp>
namespace boost { namespace filesystem {
    __declspec(dllexport) std::codecvt<unsigned short, char, std::mbstate_t> const& path::codecvt() {
        static std::locale loc(path_traits::default_locale());
        return std::use_facet<std::codecvt<unsigned short, char, std::mbstate_t> >(loc);
    }
}}
