# Vendored qpdf

Upstream: qpdf **12.4.2**, https://github.com/qpdf/qpdf (Apache-2.0, see `LICENSE.txt`
and `NOTICE.md`). Recreate with `Scripts/vendor-qpdf.sh`, which downloads the pinned
release tarball, checks its SHA-256 and copies the files below. Upstream files are not
modified.

Taken from upstream: `include/qpdf/` and `libqpdf/` (the library sources), minus the
OpenSSL and GnuTLS crypto providers, the command-line job layer (`QPDFJob*`,
`QPDFArgParser`, `qpdfjob-c`), and two files upstream ships empty.

LocalPDF-authored files:

| File | Why |
|---|---|
| `libqpdf/qpdf/qpdf-config.h` | Replaces CMake's configure step for macOS; native crypto only |
| `include/module.modulemap` | Exposes only the C API headers to Swift |
| `include/qpdf-c-localpdf.h`, `localpdf/qpdf-c-localpdf.cc` | C entry points for the C++ features PDFEngine needs that `qpdf-c.h` lacks |
| `LOCALPDF.md` | This file |
