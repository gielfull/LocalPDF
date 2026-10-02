#!/bin/bash
# Re-creates the vendored qpdf and libjpeg sources under Sources/CQPDF and Sources/CJPEG
# from pinned, checksum-verified upstream release tarballs.
#
# Only upstream files are (re)copied. The few LocalPDF-authored files in those targets
# stay as they are and are listed in Sources/CQPDF/LOCALPDF.md / Sources/CJPEG/LOCALPDF.md:
#   CQPDF/libqpdf/qpdf/qpdf-config.h   (stands in for CMake's configure step)
#   CQPDF/include/module.modulemap     (exposes only the C API to Swift)
#   CJPEG/include/jconfig.h            (stands in for libjpeg's configure step)
#
# Usage: Scripts/vendor-qpdf.sh   (run from Packages/PDFEngine; needs curl and tar only)
#
# To update: change a version and its SHA-256 below, run the script, rebuild, run the
# tests, and update THIRD_PARTY_NOTICES.md at the repository root.
set -euo pipefail

QPDF_VERSION="12.4.2"
QPDF_SHA256="8a58af5b6141319287c1883bec8bd1bd545b7567b7fc5e6ce5d25a1c85f36397"
QPDF_URL="https://github.com/qpdf/qpdf/releases/download/v${QPDF_VERSION}/qpdf-${QPDF_VERSION}.tar.gz"

JPEG_VERSION="10"
JPEG_SHA256="8b9eaa13242690ebd03e1728ab1edf97a81a78ed6e83624d493655f31ac95ab5"
JPEG_URL="https://www.ijg.org/files/jpegsrc.v${JPEG_VERSION}.tar.gz"

cd "$(dirname "$0")/.."
PACKAGE_DIR="$PWD"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fetch() { # url sha256 destination
    curl -fsSL -o "$3" "$1"
    echo "$2  $3" | shasum -a 256 -c -
}

# MARK: - qpdf

fetch "$QPDF_URL" "$QPDF_SHA256" "$WORK/qpdf.tar.gz"
tar -xzf "$WORK/qpdf.tar.gz" -C "$WORK"
QPDF_SRC="$WORK/qpdf-${QPDF_VERSION}"
QPDF_DST="$PACKAGE_DIR/Sources/CQPDF"

mkdir -p "$QPDF_DST/include/qpdf" "$QPDF_DST/libqpdf/qpdf" "$QPDF_DST/libqpdf/sph"
# Upstream-owned files are replaced wholesale; LocalPDF's own files are left alone.
find "$QPDF_DST/include/qpdf" "$QPDF_DST/libqpdf" -type f \
    ! -name qpdf-config.h -delete

cp "$QPDF_SRC"/include/qpdf/* "$QPDF_DST/include/qpdf/"
cp "$QPDF_SRC"/libqpdf/sph/* "$QPDF_DST/libqpdf/sph/"
cp "$QPDF_SRC"/libqpdf/qpdf/*.hh "$QPDF_SRC"/libqpdf/qpdf/*.h "$QPDF_DST/libqpdf/qpdf/"
cp "$QPDF_SRC"/libqpdf/*.cc "$QPDF_SRC"/libqpdf/*.c "$QPDF_DST/libqpdf/"
cp "$QPDF_SRC"/LICENSE.txt "$QPDF_SRC"/NOTICE.md "$QPDF_DST/"

# Left out of the build, matching a CMake build with only the native crypto provider:
# the OpenSSL/GnuTLS providers, the command-line job layer (QPDFJob, argument parsing),
# and two files upstream ships empty.
(cd "$QPDF_DST/libqpdf" && rm -f \
    QPDFCrypto_openssl.cc QPDFCrypto_gnutls.cc \
    qpdf/QPDFCrypto_openssl.hh qpdf/QPDFCrypto_gnutls.hh \
    QPDFJob.cc QPDFJob_argv.cc QPDFJob_config.cc QPDFJob_json.cc \
    QPDFArgParser.cc qpdf/QPDFArgParser.hh qpdfjob-c.cc \
    qpdf/QPDFJob_private.hh qpdf/auto_job_*.hh \
    QPDFNameTreeObjectHelper.cc QPDFNumberTreeObjectHelper.cc)
(cd "$QPDF_DST/include/qpdf" && rm -f QPDFJob.hh qpdfjob-c.h auto_job_*.hh)

# MARK: - libjpeg (IJG)

fetch "$JPEG_URL" "$JPEG_SHA256" "$WORK/jpeg.tar.gz"
tar -xzf "$WORK/jpeg.tar.gz" -C "$WORK"
JPEG_SRC="$WORK/jpeg-${JPEG_VERSION}"
JPEG_DST="$PACKAGE_DIR/Sources/CJPEG"

mkdir -p "$JPEG_DST/include"
find "$JPEG_DST" -type f ! -name jconfig.h ! -name LOCALPDF.md ! -name module.modulemap -delete

# The library sources from upstream's Makefile.am (LIBSOURCES), with the "no backing
# store" memory manager, the usual choice for systems with virtual memory.
JPEG_LIBSOURCES="jaricom.c jcapimin.c jcapistd.c jcarith.c jccoefct.c jccolor.c
    jcdctmgr.c jchuff.c jcinit.c jcmainct.c jcmarker.c jcmaster.c
    jcomapi.c jcparam.c jcprepct.c jcsample.c jctrans.c jdapimin.c
    jdapistd.c jdarith.c jdatadst.c jdatasrc.c jdcoefct.c jdcolor.c
    jddctmgr.c jdhuff.c jdinput.c jdmainct.c jdmarker.c jdmaster.c
    jdmerge.c jdpostct.c jdsample.c jdtrans.c jerror.c jfdctflt.c
    jfdctfst.c jfdctint.c jidctflt.c jidctfst.c jidctint.c jquant1.c
    jquant2.c jutils.c jmemmgr.c jmemnobs.c"
for file in $JPEG_LIBSOURCES; do cp "$JPEG_SRC/$file" "$JPEG_DST/"; done
cp "$JPEG_SRC"/jinclude.h "$JPEG_SRC"/jpegint.h "$JPEG_SRC"/jdct.h \
    "$JPEG_SRC"/jmemsys.h "$JPEG_SRC"/jversion.h "$JPEG_DST/"
cp "$JPEG_SRC"/jpeglib.h "$JPEG_SRC"/jmorecfg.h "$JPEG_SRC"/jerror.h "$JPEG_DST/include/"
# IJG's license requires its README to accompany any distributed source.
cp "$JPEG_SRC"/README "$JPEG_DST/"

echo "Vendored qpdf ${QPDF_VERSION} and IJG libjpeg ${JPEG_VERSION}."
