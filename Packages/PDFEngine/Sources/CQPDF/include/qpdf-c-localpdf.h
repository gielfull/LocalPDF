/*
 * LocalPDF-authored extensions to qpdf's C API, for the few things PDFEngine needs that
 * qpdf-c.h doesn't expose. Implemented in localpdf/qpdf-c-localpdf.cc with qpdf's C++
 * API, following upstream's "extend the C API" pattern (examples/extend-c-api): errors
 * are trapped by qpdf_c_wrap and read back with qpdf_get_error like any C API error.
 *
 * Every function takes a qpdf_data that has already read a file (qpdf_read).
 */

#ifndef QPDF_C_LOCALPDF_H
#define QPDF_C_LOCALPDF_H

#include <qpdf/qpdf-c.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Sets zlib's compression level to 9 for every Flate stream qpdf writes from now on, in
 * this process. qpdf keeps the level in one unsynchronized global, set here exactly once
 * under std::call_once: call this before every write, from any thread, so each write's
 * read of the level is ordered after that one store. */
void lpdf_qpdf_use_max_flate_level(void);

/* Decode and re-encode streams that are already Flate-compressed, instead of copying
 * their bytes. Call between qpdf_init_write and qpdf_write. */
void lpdf_qpdf_set_recompress_flate(qpdf_data qpdf, QPDF_BOOL value);

/* Removes fonts, images and other resources that no page's content stream uses. Only
 * done when pages share resource dictionaries (qpdf's own "auto" heuristic), the case
 * where unused resources pile up; otherwise this is a no-op. */
QPDF_ERROR_CODE lpdf_qpdf_remove_unreferenced_resources(qpdf_data qpdf);

/* Makes every reference to a byte-identical stream (same dictionary, same data) point
 * at one copy, e.g. an image or embedded font repeated in every merged file. The
 * duplicates become unreferenced and are dropped on write. Stores how many streams
 * were merged away in *merged. */
QPDF_ERROR_CODE lpdf_qpdf_deduplicate_streams(qpdf_data qpdf, int* merged);

#ifdef __cplusplus
}
#endif

#endif /* QPDF_C_LOCALPDF_H */
