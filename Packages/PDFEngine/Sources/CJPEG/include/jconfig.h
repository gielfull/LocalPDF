/*
 * jconfig.h for macOS (arm64 and x86_64, Apple clang).
 *
 * LocalPDF-authored: stands in for the output of IJG libjpeg's `configure`, which the
 * Swift package build can't run. Values follow upstream's jconfig.txt for an ANSI C
 * compiler on a 64-bit Unix, which is what configure produces on macOS.
 */

#ifndef LOCALPDF_JCONFIG_H
#define LOCALPDF_JCONFIG_H

/* jpeglib.h declares jpeg_stdio_src/dest with FILE but doesn't include <stdio.h> itself. */
#include <stdio.h>

#define HAVE_PROTOTYPES
#define HAVE_UNSIGNED_CHAR
#define HAVE_UNSIGNED_SHORT
#undef CHAR_IS_UNSIGNED
#define HAVE_STDDEF_H
#define HAVE_STDLIB_H
#undef NEED_BSD_STRINGS
#undef NEED_SYS_TYPES_H
#undef NEED_FAR_POINTERS
#undef NEED_SHORT_EXTERNAL_NAMES
#undef INCOMPLETE_TYPES_BROKEN

#ifdef JPEG_INTERNALS
#undef RIGHT_SHIFT_IS_UNSIGNED
#endif /* JPEG_INTERNALS */

#endif /* LOCALPDF_JCONFIG_H */
