# Vendored libjpeg

Upstream: the Independent JPEG Group's libjpeg, release **10** (25-Jan-2026),
https://www.ijg.org/files/jpegsrc.v10.tar.gz. The license is in `README` ("LEGAL
ISSUES"), which must accompany the source. Recreate with `Scripts/vendor-qpdf.sh`.
Upstream files are not modified.

Taken from upstream: the library sources listed as `LIBSOURCES` in its `Makefile.am`,
with the `jmemnobs.c` memory manager, and the headers they need. The command-line tools
are not included.

LocalPDF-authored files:

| File | Why |
|---|---|
| `include/jconfig.h` | Replaces libjpeg's `configure` step for macOS |
| `LOCALPDF.md` | This file |
