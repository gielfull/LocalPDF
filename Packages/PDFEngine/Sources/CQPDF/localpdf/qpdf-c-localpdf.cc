// LocalPDF-authored. See include/qpdf-c-localpdf.h.

#include <qpdf-c-localpdf.h>

#include <qpdf/Buffer.hh>
#include <qpdf/Pl_Flate.hh>
#include <qpdf/QPDF.hh>
#include <qpdf/QPDFObjectHandle.hh>
#include <qpdf/QPDFPageDocumentHelper.hh>
#include <qpdf/QPDFWriter.hh>
// Private: the C API's handle layout, for the writer it creates in qpdf_init_write. Pinned
// with the vendored version; re-check when updating qpdf.
#include <qpdf/qpdf-c_impl.hh>

#include <cstring>
#include <list>
#include <map>
#include <mutex>
#include <set>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace
{
    // MARK: Unreferenced resources

    // Port of QPDFJob::shouldRemoveUnreferencedResources (QPDFJob isn't vendored): true when
    // a page-tree node carries resources, or pages/forms share a resources dictionary or its
    // /XObject subdictionary.
    bool
    has_shared_resources(QPDF& pdf)
    {
        std::set<QPDFObjGen> resources_seen;
        std::set<QPDFObjGen> nodes_seen;
        std::list<QPDFObjectHandle> queue;
        queue.emplace_back(pdf.getRoot().getKey("/Pages"));
        while (!queue.empty()) {
            QPDFObjectHandle node = queue.front();
            queue.pop_front();
            if (node.isIndirect() && !nodes_seen.insert(node.getObjGen()).second) {
                continue;
            }
            QPDFObjectHandle dict = node.isStream() ? node.getDict() : node;
            if (!dict.isDictionary()) {
                continue;
            }
            QPDFObjectHandle kids = dict.getKey("/Kids");
            if (kids.isArray()) {
                if (dict.hasKey("/Resources")) {
                    return true;
                }
                for (int i = 0; i < kids.getArrayNItems(); ++i) {
                    queue.emplace_back(kids.getArrayItem(i));
                }
                continue;
            }
            QPDFObjectHandle resources = dict.getKey("/Resources");
            if (resources.isIndirect() && !resources_seen.insert(resources.getObjGen()).second) {
                return true;
            }
            if (!resources.isDictionary()) {
                continue;
            }
            QPDFObjectHandle xobjects = resources.getKey("/XObject");
            if (xobjects.isIndirect() && !resources_seen.insert(xobjects.getObjGen()).second) {
                return true;
            }
            if (!xobjects.isDictionary()) {
                continue;
            }
            for (auto const& key: xobjects.getKeys()) {
                QPDFObjectHandle xobject = xobjects.getKey(key);
                if (xobject.isStream() && xobject.getDict().getKey("/Subtype").isNameAndEquals("/Form")) {
                    queue.emplace_back(xobject);
                }
            }
        }
        return false;
    }

    // MARK: Deduplication

    using Remap = std::map<QPDFObjGen, QPDFObjectHandle>;

    // Points references inside `object` (its direct contents, recursively) at their
    // replacements. Indirect objects are not entered: each is visited on its own.
    void
    remap_references(QPDFObjectHandle object, Remap const& remap)
    {
        if (object.isStream()) {
            remap_references(object.getDict(), remap);
        } else if (object.isArray()) {
            int count = object.getArrayNItems();
            for (int i = 0; i < count; ++i) {
                QPDFObjectHandle item = object.getArrayItem(i);
                if (item.isIndirect()) {
                    auto found = remap.find(item.getObjGen());
                    if (found != remap.end()) {
                        object.setArrayItem(i, found->second);
                    }
                } else {
                    remap_references(item, remap);
                }
            }
        } else if (object.isDictionary()) {
            for (auto const& key: object.getKeys()) {
                QPDFObjectHandle value = object.getKey(key);
                if (value.isIndirect()) {
                    auto found = remap.find(value.getObjGen());
                    if (found != remap.end()) {
                        object.replaceKey(key, found->second);
                    }
                } else {
                    remap_references(value, remap);
                }
            }
        }
    }

    bool
    same_bytes(std::shared_ptr<Buffer> const& a, std::shared_ptr<Buffer> const& b)
    {
        return a->getSize() == b->getSize() &&
            (a->getSize() == 0 || std::memcmp(a->getBuffer(), b->getBuffer(), a->getSize()) == 0);
    }

    // A stream's raw data, summarized: equal data gives an equal digest. Collisions are
    // harmless, because a digest match is confirmed byte by byte before merging.
    std::pair<size_t, size_t>
    digest(std::shared_ptr<Buffer> const& data)
    {
        std::string_view bytes(reinterpret_cast<char const*>(data->getBuffer()), data->getSize());
        return {std::hash<std::string_view>{}(bytes), data->getSize()};
    }

    // One pass: finds streams equal to an earlier one and points every reference at the
    // earlier one. Adds the merged-away streams to `merged` (later passes skip them) and
    // returns how many there were.
    int
    deduplicate_pass(QPDF& pdf, std::set<QPDFObjGen>& merged)
    {
        // Streams grouped by dictionary (minus /Length) and length; only groups with more than
        // one member have their data read. A /Length that isn't a direct integer counts as -1,
        // so such groups can be large (every page image of a Ghostscript scan): memory stays
        // bounded because only digests are kept, never the data of the streams kept so far.
        std::map<std::pair<std::string, long long>, std::vector<QPDFObjectHandle>> groups;
        std::vector<QPDFObjectHandle> all = pdf.getAllObjects();
        for (auto& object: all) {
            if (!object.isStream() || merged.count(object.getObjGen())) {
                continue;
            }
            QPDFObjectHandle dict = object.getDict();
            QPDFObjectHandle type = dict.getKey("/Type");
            if (type.isNameAndEquals("/XRef") || type.isNameAndEquals("/ObjStm")) {
                continue;
            }
            QPDFObjectHandle length = dict.getKey("/Length");
            long long size = length.isInteger() ? length.getIntValue() : -1;
            QPDFObjectHandle signature = dict.shallowCopy();
            signature.removeKey("/Length");
            groups[{signature.unparse(), size}].push_back(object);
        }

        Remap remap;
        for (auto& [key, members]: groups) {
            if (members.size() < 2) {
                continue;
            }
            // The streams kept so far, by digest of their data. At most two streams' data are
            // in memory at once: the current one, and a kept one being compared against it.
            std::map<std::pair<size_t, size_t>, std::vector<QPDFObjectHandle>> kept;
            for (auto& stream: members) {
                std::shared_ptr<Buffer> data = stream.getRawStreamData();
                auto& sameDigest = kept[digest(data)];
                bool duplicate = false;
                for (auto& keptStream: sameDigest) {
                    if (same_bytes(data, keptStream.getRawStreamData())) {
                        remap[stream.getObjGen()] = keptStream;
                        merged.insert(stream.getObjGen());
                        duplicate = true;
                        break;
                    }
                }
                if (!duplicate) {
                    sameDigest.push_back(stream);
                }
            }
        }
        if (remap.empty()) {
            return 0;
        }
        for (auto& object: all) {
            remap_references(object, remap);
        }
        remap_references(pdf.getTrailer(), remap);
        return static_cast<int>(remap.size());
    }
} // namespace

extern "C" void
lpdf_qpdf_use_max_flate_level(void)
{
    static std::once_flag once;
    std::call_once(once, [] { Pl_Flate::setCompressionLevel(9); });
}

extern "C" void
lpdf_qpdf_set_recompress_flate(qpdf_data qpdf, QPDF_BOOL value)
{
    if (qpdf->qpdf_writer) {
        qpdf->qpdf_writer->setRecompressFlate(value != QPDF_FALSE);
    }
}

extern "C" QPDF_ERROR_CODE
lpdf_qpdf_remove_unreferenced_resources(qpdf_data qpdf)
{
    return qpdf_c_wrap(qpdf, [qpdf]() {
        QPDF& pdf = *qpdf_c_get_qpdf(qpdf);
        if (has_shared_resources(pdf)) {
            QPDFPageDocumentHelper(pdf).removeUnreferencedResources();
        }
    });
}

extern "C" QPDF_ERROR_CODE
lpdf_qpdf_deduplicate_streams(qpdf_data qpdf, int* merged)
{
    *merged = 0;
    return qpdf_c_wrap(qpdf, [qpdf, merged]() {
        QPDF& pdf = *qpdf_c_get_qpdf(qpdf);
        std::set<QPDFObjGen> merged_away;
        // An image and its soft mask are both streams: once the masks are merged, the images
        // that pointed at them become equal too. A few passes reach that fixed point.
        for (int pass = 0; pass < 4; ++pass) {
            int count = deduplicate_pass(pdf, merged_away);
            *merged += count;
            if (count == 0) {
                break;
            }
        }
    });
}
