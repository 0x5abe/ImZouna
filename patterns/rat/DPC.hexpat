#pragma MIME application/x-dpc

#include <zouna.hexpat>

struct BlockDescription {
    u32 object_count;
    u32 padded_size;
    u32 data_size;
    u32 working_buffer_offset;
    Name_Z first_object_name;
    i32 block_checksum;
};

struct VersionTriple {
    u32 _0;
    u32 _1;
    u32 _2;
};

struct Header {
    char version[256];
    u32 flags; // 0x1 means the DPC contains compressed objects
    u32 block_count;
    u32 block_working_buffer_capacity_even;
    u32 block_working_buffer_capacity_odd;
    u32 total_padded_block_size;
    VersionTriple version_triple;
    BlockDescription block_descriptions[block_count];
    BlockDescription empty_block_descriptions[64 - block_count];
    u32 pool_manifest_padded_size;
    u32 pool_manifest_offset;
    u32 pool_manifest_unused0;
    u32 pool_manifest_unused1;
    std::assert(pool_manifest_unused0 == pool_manifest_unused1, "pool_manifest_unused0 != pool_manifest_unused1");
    u32 pool_object_decompression_buffer_capacity;
    u32 block_sector_padding_size;
    u32 pool_sector_padding_size;
    u32 file_size;
    char incredi_builder_string[128];
    u8 pad[64];
};

struct ObjectHeader {
    u32 data_size;
    u32 link_header_size;
    u32 decompressed_size;
    u32 compressed_size;
    Name_Z class_name;
    Name_Z object_name;
    std::assert(compressed_size == 0 || compressed_size <= float(decompressed_size) * 0.80, "20% minimum compression expectation violated");
};

struct BlockObject {
    ObjectHeader header;
    u8 data[header.data_size];
};

struct Block {
    BlockObject objects[parent.header.block_descriptions[std::core::array_index()].object_count];
    std::mem::AlignTo<2048>;
};

struct ReferenceRecord {
    u32 start_chunk_index;
    u32 end_chunk_index;
    u32 object_names_starting_index;
    u16 placeholder_dpc_index;
    u16 object_names_count;
    u32 placeholder_times_referenced;
    u32 placeholder_current_references_shared;
    u32 placeholder_current_references_weak;
};

struct PoolManifest {
    u32 equals0x80000;
    //std::assert(equals0x80000 == 0x80000, "equals0x80000 != 0x80000");
    u32 equals0x800;
    //std::assert(equals0x800 == 0x800, "equals0x800 != 0x800");
    u32 object_names_count_sum;
    DynArray_Z<u32> object_names_indices;
    DynArray_Z<Name_Z> object_names;
    DynArray_Z<u32> reference_counts;
    DynArray_Z<u32> object_padded_size;
    DynArray_Z<u32> reference_records_indices;
    DynArray_Z<ReferenceRecord> reference_records;
    std::assert(object_names.size == reference_counts.size, "object_names.size != reference_counts.size");
    std::assert(reference_counts.size == object_padded_size.size, "reference_counts.size != object_padded_size.size");
    std::assert(object_padded_size.size == reference_records_indices.size, "object_padded_size.size != reference_records_indices.size");
    std::assert(reference_records_indices.size == reference_records.size, "reference_records_indices.size != reference_records.size");
    ReferenceRecord terminal;
};

struct PoolObject : BlockObject {
    std::mem::AlignTo<2048>;
};

struct Pool {
    PoolManifest pool_manifest;
    std::mem::AlignTo<2048>;
    PoolObject pool_objects[pool_manifest.object_names_indices.size];
};

fn calculate_padded_size(u32 unpadded_size) {
    return (unpadded_size + 0x7ff) & 0xfffff800;
};

fn calculate_padding_size(u32 unpadded_size) {
    return calculate_padded_size(unpadded_size) - unpadded_size;
};

// Block object ordering used by the Wall-E PSP bigfile builder
// -----------------------------------------------------------------------------
// P_EVE.DPP and its DPP.LAYOUT/NPP sidecars reveal that the size used for
// packing is the serialized disk size of an object: the 0x18-byte ObjectHeader
// plus ObjectHeader::data_size.  The layout calls this value the object's disk
// space.  Dependencies and classes do not determine block membership.
//
// The builder appears to maintain two packing ceilings, one for even blocks and
// one for odd blocks.  Block 0 takes the largest remaining object and establishes
// the even ceiling by rounding that object's disk size up to 0x800.  Block 1 does
// the same for the odd ceiling.  Every later block reuses the ceiling belonging
// to its parity.
//
// A block is filled greedily.  Its largest remaining object is selected first;
// after that, the builder repeatedly selects the largest remaining object whose
// disk size fits in the space still available.  Selection stops when no remaining
// object fits.  Selected objects are stored in the opposite direction, so their
// on-disk order is nondecreasing and the largest/anchor object is last.  The last
// block simply contains all remaining objects and its stored padded_size shrinks
// to the 0x800-aligned size actually used instead of being padded to its parity's
// full packing ceiling.
//
// Equal-sized objects are intentionally interchangeable here.  Which name wins
// a tie depends on the builder's sort stability and the input array order, but it
// cannot change the packing or the serialized-size ordering.
// scripts/validate_dpc_object_order.py reconstructs this process efficiently and
// validates it against every Wall-E PSP DPP/NPP/DPP.LAYOUT triplet.

fn block_assert(ref auto header, ref auto block, u32 block_index) {
    u32 object_count = header.block_descriptions[block_index].object_count;
    u32 block_address = addressof(block);
    u32 calculated_offset = 0;

    for (u32 i = 0, i < object_count, i += 1) {
        // if (block.objects[i].header.compressed_size != 0) {
        //     u32 required_size = block.objects[i].header.decompressed_size;
        //     u32 available_size = addressof(block.objects[i].data) - block_address;
        //     if (required_size > available_size) {
        //       calculated_offset = std::math::max(calculated_offset, calculate_padded_size(required_size - available_size));
        //     }
        // }
        calculated_offset = std::math::max(calculated_offset, calculate_padded_size(block.objects[i].header.decompressed_size));
    }

    std::print("{} / 2048 = {}", calculated_offset, calculated_offset / 2048);

    return true;
};

fn blocks_assert(ref auto header, ref auto blocks) {
    for (u32 i = 0, i < std::core::member_count(blocks), i += 1) {
        if (!block_assert(header, blocks[i], i)) {
            return false;
        }
    }

    return true;
};

fn objects_not_compressed(ref auto blocks) {
    for (u32 block_index = 0, block_index < std::core::member_count(blocks), block_index += 1) {
        for (u32 object_index = 0, object_index < std::core::member_count(blocks[block_index].objects), object_index += 1) {
            if (blocks[block_index].objects[object_index].header.compressed_size != 0) {
                return false;
            }
        }
    }

    return true;
};

fn print_compression_statistics(ref auto blocks) {
    for (u32 block_index = 0, block_index < std::core::member_count(blocks), block_index += 1) {
        u32 compressed_object_count = 0;
        u32 object_count = std::core::member_count(blocks[block_index].objects);

        for (u32 object_index = 0, object_index < object_count, object_index += 1) {
            if (blocks[block_index].objects[object_index].header.compressed_size != 0) {
                compressed_object_count += 1;
            }
        }

        std::print("IMZOUNA_STAT block_compression {} {} {}", block_index, compressed_object_count, object_count);
    }
};

fn block_working_buffer_capacities_valid(ref auto header) {
    if (header.block_count == 0) {
        return true;
    }

    u32 calculated_even_capacity = 0;
    u32 calculated_odd_capacity = 0;

    for (u32 block_index = 0, block_index < header.block_count, block_index += 1) {
        u32 required_capacity = header.block_descriptions[block_index].working_buffer_offset + header.block_descriptions[block_index].padded_size;
        if (block_index % 2 == 0) {
            calculated_even_capacity = std::math::max(calculated_even_capacity, required_capacity);
        } else {
            calculated_odd_capacity = std::math::max(calculated_odd_capacity, required_capacity);
        }
    }

    if (calculated_even_capacity != header.block_working_buffer_capacity_even) {
        return false;
    }

    return header.block_count == 1 || calculated_odd_capacity == header.block_working_buffer_capacity_odd;
};

fn block_working_buffer_offsets_cover_decompression(ref auto header, ref auto blocks) {
    for (u32 block_index = 0, block_index < header.block_count, block_index += 1) {
        u32 block_address = addressof(blocks[block_index]);
        u32 minimum_working_buffer_offset = 0;
        u32 total_link_header_size = 0;
        u32 compressed_link_header_size = 0;
        u32 link_header_size_through_last_compressed_object = 0;

        for (u32 object_index = 0, object_index < std::core::member_count(blocks[block_index].objects), object_index += 1) {
            total_link_header_size += blocks[block_index].objects[object_index].header.link_header_size;
            if (blocks[block_index].objects[object_index].header.compressed_size != 0) {
                compressed_link_header_size += blocks[block_index].objects[object_index].header.link_header_size;
                link_header_size_through_last_compressed_object = total_link_header_size;
                u32 source_offset = addressof(blocks[block_index].objects[object_index].data) - block_address;
                u32 decompressed_size = blocks[block_index].objects[object_index].header.decompressed_size;
                if (decompressed_size > source_offset) {
                    minimum_working_buffer_offset = std::math::max(minimum_working_buffer_offset, calculate_padded_size(decompressed_size - source_offset));
                }
            }
        }

        if (header.block_descriptions[block_index].working_buffer_offset < minimum_working_buffer_offset) {
            return false;
        }

#ifdef IMZOUNA_COLLECT_STATS
        u32 working_buffer_capacity;
        if (block_index % 2 == 0) {
            working_buffer_capacity = header.block_working_buffer_capacity_even;
        } else {
            working_buffer_capacity = header.block_working_buffer_capacity_odd;
        }
        u32 trailing_space = working_buffer_capacity - header.block_descriptions[block_index].working_buffer_offset - header.block_descriptions[block_index].padded_size;
        std::print("IMZOUNA_STAT block_working_offset {} {} {} {} {} {} {}", block_index, header.block_descriptions[block_index].working_buffer_offset, minimum_working_buffer_offset, trailing_space, total_link_header_size, compressed_link_header_size, link_header_size_through_last_compressed_object);
#endif
    }

    return true;
};

struct DPC {
    Header header;
    Block blocks[header.block_count];
    // std::assert(blocks_assert(header, blocks), "!blocks_assert(header, blocks)");
};

DPC dpc @ 0x0;

#ifdef IMZOUNA_COLLECT_STATS
print_compression_statistics(dpc.blocks);
#endif

std::assert(block_working_buffer_capacities_valid(dpc.header), "Even/odd block working buffer capacity != maximum working_buffer_offset + padded_size");
std::assert(block_working_buffer_offsets_cover_decompression(dpc.header, dpc.blocks), "Block working_buffer_offset is smaller than its in-place decompression requirement");
std::assert((dpc.header.flags & 0x1) != 0 || objects_not_compressed(dpc.blocks), "DPC without compression flag contains a compressed object");
std::assert(std::mem::eof(), "Whole input not consumed");
