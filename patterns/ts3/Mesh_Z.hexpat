#pragma MIME application/x-mesh-z

#include <zouna.hexpat>

// Asobo Studio Mesh_Z v1.634.78.10
// Platforms currently supported: PlayStation 2 and PlayStation Portable.

// -----------------------------------------------------------------------------
// Shared Mesh_Z
// -----------------------------------------------------------------------------

struct Mesh_Z_LinkHeaderV1_634_78_10 : Object_Z {
    DynArray_Z<Name_Z> linked_resources;

    FadeDistances fade;

    DynArray_Z<SphereCol_Z> sphere_cols;
    DynArray_Z<BoxCol_Z> box_cols;
};

// Tangent Binormal Vertex - From Monopoly MAP
struct TBVtx {
    Vec3f tangent;
    f32 handedness;
};

struct Points_ZV1_634_78_10 : Mesh_Z_LinkHeaderV1_634_78_10 {
    DynArray_Z<Vec3f> positions;
    std::assert(positions.size == 0, "positions.size != 0");

    DynArray_Z<TBVtx> tb_vertices;
    std::assert(tb_vertices.size == 0, "tb_vertices.size != 0");
};

struct FaceCol_Z {
    i16 first_vertex_idx;
    i16 second_vertex_idx;
    i16 third_vertex_idx;
    i16 material_idx;
};

using RangeBeginSizeS16_Z = RangeBeginSizeBase<i16>;

struct AABBNode_Z {
    Vec3f bb_min;
    i16 left_child_index_plus_one;
    i16 right_child_index_plus_one;

    Vec3f bb_max;
    RangeBeginSizeS16_Z collision_faces_range;
};

struct AABBCol_Z {
    DynArray_Z<AABBNode_Z> aabb_nodes;
    DynArray_Z<FaceCol_Z> face_cols;
};

using Vec3f_S16_10_Z = Vec<NumeratorFloat<i16, 1024>, 3>;

struct MorphValue_Z {
    Vec3f_S16_10_Z displacement;
    u16 self_idx;
};

struct MorphTargetDesc_Z {
    PascalString name;

    u32 base_vertex_buffer_id;
    u16 displacement_vertex_buffer_index;

    DynArray_Z<u16> vertex_indices;
    DynArray_Z<MorphValue_Z> morph_values;
};

struct Morpher_Z {
    DynArray_Z<AABBNode_Z> aabb_nodes;
    Map_Z<u16, u16> map;
    DynArray_Z<u16> displacement_indices;
    DynArray_Z<MorphTargetDesc_Z> morphs;
};

struct VertexBufferExt_Z {
    u32 vertex_count;
    u32 vertex_stride;
    u32 unknown;

    u8 raw_vertices[vertex_count * vertex_stride];
};

struct IndexBufferExt_Z {
    u32 index_count;
    u32 unknown;

    u16 indices[index_count];
};

struct PrimitiveInfo_Z {
    u32 zero_0;
    u32 zero_1;
    u32 zero_2;

    u32 primitive_type_or_unknown;

    u16 vertex_offset_in_buffer_in_groups;
    u16 unknown_0;

    u32 vertex_count;
    u32 index_buffer_offset_in_u16s;
    u32 face_count;
    u32 unknown_1;
    u32 unknown_2;

    u16 vertex_stride;
    u16 debug_fill_or_unknown;
};

struct Unknown28Byte_Z {
    u8 data[28];
};

struct UnknownMeshBufferStruct_Z {
    u8 data[48];
    DynArray_Z<Unknown28Byte_Z> substructs;
};

struct MeshBuffers_Z {
    DynArray_Z<VertexBufferExt_Z> vertex_buffers;
    DynArray_Z<IndexBufferExt_Z> index_buffers;
    DynArray_Z<PrimitiveInfo_Z> vertex_groups;
    DynArray_Z<UnknownMeshBufferStruct_Z> unknown_structs;
};

struct Strip_Z {
    DynArray_Z<u16> strip_vertex_indices;
    Name_Z material_name;

    /// Observed values are 1 or 2.
    u32 tri_order;
};

struct Vtx_Z {
    u16 uv_idx;
    u16 normal_idx;
    u16 color_idx;
    u16 vertices_idx;
    u16 unk_idx;
};

struct StripExt_Z {
    DynArray_Z<Vtx_Z> vertices;
};

bitfield EdgeColFlags_Z {
    reverse_side : 1;
    padding : 31;
};

bitfield EdgeColTypeFlags_Z {
    enabled : 1;
    padding : 31;
};

struct EdgeCol_Z {
    Sphere_Z sphere;
    EdgeColFlags_Z flags;
    EdgeColTypeFlags_Z type_flags;
    u16 vertex_indices[2];
    u32 edge_idx;
};

struct Mesh_ZV1_634_78_10 : Points_ZV1_634_78_10 {
    std::assert(type == ObjectType::Mesh_Z, "type != ObjectType::Mesh_Z");

    DynArray_Z<Vec2f> texcoords;
    DynArray_Z<Vec3f> normals;
    DynArray_Z<u32> unknown_minus_one;

    DynArray_Z<Strip_Z> strips;

    if (flags.FL_OBJECT_SKINNED) {
        u32 strip_override_material_indices[strips.size];
    }

    DynArray_Z<StripExt_Z> strip_exts;
    DynArray_Z<Name_Z> material_names;

    AABBCol_Z aabb_col;

    DynArray_Z<EdgeCol_Z> cling_edges;

    MeshBuffers_Z mesh_buffers;

    Morpher_Z morpher;

    /// Used for AABB collision
    DynArray_Z<Vec3i16> optimized_vertices;
};

// -----------------------------------------------------------------------------
// PlayStation 2
// -----------------------------------------------------------------------------

struct Qword_Z {
    u32 data[4] [[inline]];
};

struct SubMesh_Z {
    u8 material_idx;

    /// Prebuilt DMA / VIF1 / VU1 data
    DynArray_Z<Qword_Z> dma_packet;
};

struct MeshPs2_ZV1_634_78_10 : Mesh_ZV1_634_78_10 {
    DynArray_Z<SubMesh_Z> sub_meshes;
};

using MeshPs2_Z = le MeshPs2_ZV1_634_78_10;

// -----------------------------------------------------------------------------
// PlayStation Portable
// -----------------------------------------------------------------------------

enum GeCommandOpcode : u8 {
    VADDR  = 0x01,
    PRIM   = 0x04,
    JUMP   = 0x08,
    RET    = 0x0B,
    BASE   = 0x10,
    VTYPE  = 0x12,
    ORIGIN = 0x14,
};

enum GePrimitiveType : u32 {
    GU_POINTS         = 0,
    GU_LINES          = 1,
    GU_LINE_STRIP     = 2,
    GU_TRIANGLES      = 3,
    GU_TRIANGLE_STRIP = 4,
    GU_TRIANGLE_FAN   = 5,
    GU_SPRITES        = 6,
};

enum KnownPSPVertexType : u32 {
    /// UV S16x2, color 4444, normal S8x3, position S16x3.
    Static = 0x00013A,

    /// Four U8 weights, UV S16x2, normal S8x3, position S16x3.
    Skinned = 0x00C322,
};

struct GeCommand_Z {
    u32 raw;

    GeCommandOpcode opcode = raw >> 24 [[hidden]];
    u32 argument = raw & 0x00FFFFFF [[hidden]];
};

using PSPBlendWeight = NumeratorFloat<u8, 128>;
using PSPBlendWeights4 = Vec<PSPBlendWeight, 4>;
using PSPNormalComponent = NumeratorFloat<i8, 64>;
using PSPNormal = Vec<PSPNormalComponent, 3>;

// VTYPE 0x00C322
struct SkinVertexPSP_Z {
    PSPBlendWeights4 weights;
    Vec2i16 uv;

    PSPNormal normal;
    u8 normal_alignment;

    Vec3i16 position;
};

// VTYPE 0x00013A
struct MeshVertexPSP_Z {
    Vec2i16 uv;
    u16 color_4444;

    PSPNormal normal;
    u8 normal_alignment;

    Vec3i16 position;
};

struct GeDrawFooter_Z {
    GeCommand_Z vertex_type;
    GeCommand_Z vertex_base;
    GeCommand_Z vertex_address;
    GeCommand_Z primitive;
    GeCommand_Z final_origin;
    GeCommand_Z list_return;
};

// Callable/relocatable GE data. The list jumps over its embedded vertices, draws them, then returns to the caller.
struct CallableDisplayListData_Z<auto ByteCount> {
    u64 data_address = $ [[hidden]];

    GeCommand_Z initial_origin;
    GeCommand_Z initial_base;
    GeCommand_Z jump_to_draw;

    std::assert(initial_origin.opcode == GeCommandOpcode::ORIGIN,
        "Expected GE ORIGIN at start of callable display list");
    std::assert(initial_base.opcode == GeCommandOpcode::BASE,
        "Expected GE BASE after ORIGIN");
    std::assert(jump_to_draw.opcode == GeCommandOpcode::JUMP,
        "Expected GE JUMP after BASE");

    u32 draw_command_offset = jump_to_draw.argument [[hidden]];

    std::assert(draw_command_offset >= 12,
        "GE draw commands overlap the initial display-list commands");
    std::assert(draw_command_offset + 24 <= ByteCount,
        "GE draw footer exceeds display-list ByteCount");

    u32 vertex_type_word = std::mem::read_unsigned(
        data_address + draw_command_offset,
        4
    ) [[hidden]];

    u32 vertex_address_word = std::mem::read_unsigned(
        data_address + draw_command_offset + 8,
        4
    ) [[hidden]];

    u32 primitive_word = std::mem::read_unsigned(
        data_address + draw_command_offset + 12,
        4
    ) [[hidden]];

    u32 vertex_type = vertex_type_word & 0x00FFFFFF [[hidden]];
    u32 vertex_data_offset = vertex_address_word & 0x00FFFFFF [[hidden]];
    GePrimitiveType primitive_type = (primitive_word >> 16) & 0x7 [[hidden]];
    u32 vertex_count = primitive_word & 0x0000FFFF [[hidden]];

    std::assert(vertex_data_offset >= 12,
        "GE vertex address overlaps the initial display-list commands");
    std::assert(vertex_data_offset <= draw_command_offset,
        "GE vertex data starts after its draw commands");

    u8 pre_vertex_padding[vertex_data_offset - 12];

    u32 vertex_data_size = draw_command_offset - vertex_data_offset [[hidden]];
    u32 vertex_stride = 0 [[hidden]];

    if (vertex_count != 0) {
        vertex_stride = vertex_data_size / vertex_count;
    }

    if (vertex_type == KnownPSPVertexType::Skinned &&
        vertex_stride == 18 &&
        vertex_data_size == vertex_count * 18) {

        SkinVertexPSP_Z vertices[vertex_count];

    } else if (vertex_type == KnownPSPVertexType::Static &&
               vertex_stride == 16 &&
               vertex_data_size == vertex_count * 16) {

        MeshVertexPSP_Z vertices[vertex_count];

    } else {
        u8 raw_vertex_data[vertex_data_size];
    }

    GeDrawFooter_Z draw_footer;

    std::assert(draw_footer.vertex_type.opcode == GeCommandOpcode::VTYPE,
        "Expected GE VTYPE in draw footer");
    std::assert(draw_footer.vertex_address.opcode == GeCommandOpcode::VADDR,
        "Expected GE VADDR in draw footer");
    std::assert(draw_footer.primitive.opcode == GeCommandOpcode::PRIM,
        "Expected GE PRIM in draw footer");
    std::assert(draw_footer.final_origin.opcode == GeCommandOpcode::ORIGIN,
        "Expected GE ORIGIN before RET");
    std::assert(draw_footer.list_return.opcode == GeCommandOpcode::RET,
        "Expected GE RET at end of callable display list");

    u32 trailing_padding_size = ByteCount - draw_command_offset - 24 [[hidden]];
    u8 trailing_padding[trailing_padding_size];
};

// Non-callable static data
struct StaticDisplayListData_Z<
    auto ByteCount,
    auto VertexType,
    auto VertexCountAndFlags
> {
    u32 vertex_count = VertexCountAndFlags & 0x0000FFFF [[hidden]];
    u32 vertex_flags = VertexCountAndFlags >> 16 [[hidden]];

    if (VertexType == KnownPSPVertexType::Static &&
        vertex_count * 16 <= ByteCount) {

        MeshVertexPSP_Z vertices[vertex_count];
        u8 trailing_padding[ByteCount - vertex_count * 16];

    } else {
        u8 raw_data[ByteCount];
    }
};

// A list consists of a 0x60-byte metadata header after byte_count,
// followed by exactly byte_count bytes of GE commands and/or embedded vertex data.
struct DisplayList_Z {
    u32 byte_count;
    u32 zero;

    /// In skinned lists these identify the skeleton bones assigned to the GE's
    /// four implicit weight slots. Static lists use -1 in all four entries.
    Name_Z bone_palette[4];

    /// Static list metadata:
    ///   primitive_type         = 4         (GU_TRIANGLE_STRIP)
    ///   vertex_type            = 0x13A
    ///   vertex_count_and_flags
    /// Callable skinned lists store zero in these fields; their GE footer carries
    /// the actual VTYPE, primitive type and vertex count.
    u32 primitive_type;
    u32 vertex_type;
    u32 vertex_count_and_flags;

    /// Scale/translation matrix used with the quantized S16 positions.
    Mat4f position_decode_transform;

    std::assert(zero == 0, "DisplayList_Z zero != 0");

    u64 data_address = $ [[hidden]];
    u32 first_data_word = 0 [[hidden]];
    u32 second_data_word = 0 [[hidden]];
    u32 third_data_word = 0 [[hidden]];

    if (byte_count >= 12) {
        first_data_word = std::mem::read_unsigned(data_address, 4);
        second_data_word = std::mem::read_unsigned(data_address + 4, 4);
        third_data_word = std::mem::read_unsigned(data_address + 8, 4);
    }

    bool is_callable_ge_list =
        ((first_data_word >> 24) == 0x14) &&
        ((second_data_word >> 24) == 0x10) &&
        ((third_data_word >> 24) == 0x08) [[hidden]];

    if (is_callable_ge_list) {
        CallableDisplayListData_Z<byte_count> data;
    } else if (vertex_type == KnownPSPVertexType::Static) {
        StaticDisplayListData_Z<
            byte_count,
            vertex_type,
            vertex_count_and_flags
        > data;
    } else {
        /// Preserve unknown PSP layouts instead of forcing one of the two
        /// currently observed formats.
        u8 raw_data[byte_count];
    }
};


struct MeshPSP_ZV1_634_78_10 : Mesh_ZV1_634_78_10 {
    DynArray_Z<DisplayList_Z> display_lists;
    DynArray_Z<Name_Z> material_link_names;

    std::assert(material_link_names.size == display_lists.size,
        "material_link_names.size != display_lists.size");
};

using MeshPSP_Z = le MeshPSP_ZV1_634_78_10;

// -----------------------------------------------------------------------------
// Platform dispatch
// -----------------------------------------------------------------------------


struct MeshFile_Z {
    u64 start_address = $ [[hidden]];

    BffHeader platform_probe [[hidden]];

    $ = start_address;

    match (platform_probe.platform) {
        (Platform::PS2): {
            MeshPs2_Z mesh;
        }

        (Platform::PSP): {
            MeshPSP_Z mesh;
        }

        (_): {
            std::assert(false,
                "Unsupported platform for Mesh_Z v1.634.78.10");
        }
    }
};

MeshFile_Z mesh_z @ 0x0;

std::assert(std::mem::eof(), "Whole input not consumed");
