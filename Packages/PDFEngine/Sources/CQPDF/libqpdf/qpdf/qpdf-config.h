/*
 * qpdf-config.h for macOS (arm64 and x86_64, Apple clang, macOS SDK).
 *
 * LocalPDF-authored: stands in for the file CMake generates from qpdf-config.h.in, which
 * the Swift package build can't run. Values are what qpdf's CMake checks find on macOS,
 * with the crypto provider fixed to qpdf's own ("native") implementation: no OpenSSL or
 * GnuTLS is linked. Random data comes from the OS (SecureRandomDataProvider, /dev/urandom).
 */

/* options */
#define DEFAULT_CRYPTO "native"
#define USE_CRYPTO_NATIVE 1
/* not defined: AVOID_WINDOWS_HANDLE, USE_CRYPTO_GNUTLS, USE_CRYPTO_OPENSSL,
   USE_INSECURE_RANDOM, SKIP_OS_SECURE_RANDOM, ZOPFLI */

/* large file support: off_t is 64-bit on every macOS architecture, no macro needed. */

/* headers files */
#define HAVE_INTTYPES_H 1
#define HAVE_STDINT_H 1

/* OS functions and symbols */
#define HAVE_EXTERN_LONG_TIMEZONE 1
#define HAVE_FSEEKO 1
#define HAVE_LOCALTIME_R 1
#define HAVE_RANDOM 1
#define HAVE_TM_GMTOFF 1
#define HAVE_OPEN_MEMSTREAM 1
/* not defined: HAVE_FSEEKO64, HAVE_MALLOC_INFO (glibc only) */

/* bytes in the size_t type */
#define SIZEOF_SIZE_T 8
