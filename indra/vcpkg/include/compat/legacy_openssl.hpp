#ifndef legacy_opensll_hpp
#define legacy_opensll_hpp

#ifdef ERROR
#undef ERROR
#endif
#include <openssl/evp.h>
namespace legacy_openssl {
	struct EVP_CIPHER_CTX {
		::EVP_CIPHER_CTX *ptr { ::EVP_CIPHER_CTX_new() };
		::EVP_CIPHER_CTX* operator&() { return ptr; }
		//EVP_CIPHER_CTX* operator&() const { return ptr; }
    ~EVP_CIPHER_CTX() { EVP_CIPHER_CTX_free(ptr); ptr = nullptr; }
	};
}

#endif /* end of include guard: legacy_opensll_hpp */

