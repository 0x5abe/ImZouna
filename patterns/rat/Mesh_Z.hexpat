#pragma MIME application/x-mesh-z

#include <zouna.hexpat>

struct ResourceObject_ZV1_06_63_02 : BaseObject_Z {
    Name_Z link_name;
    DynArray_Z<Name_Z> linked_resources;
};

struct Object_ZV1_06_63_02 : ResourceObject_ZV1_06_63_02 {
    Name_Z data_name;
    Sphere_Z b_sphere_local;
    Box_Z b_box_local;
    f32 fadeout_distance;
    ObjectFlags flags;
    ObjectType type;
};

// Tangent Binormal Vertex ? - From Monopoly MAP
struct TBVtx {
    Vec2f unknown0;
    Vec2f unknown1;
};

struct MorphValue_Z {
    u8 pad[16];
};

struct MorphTargetDesc_Z {
    Name_Z mesh_name;
    DynArray_Z<MorphValue_Z> morph_values;
};

struct Morpher_Z {
    DynArray_Z<MorphValue_Z> morph_values;
    std::assert(morph_values.size == 0, "morph_values.size != 0");
    
    DynArray_Z<MorphTargetDesc_Z> morphs;
    std::assert(morphs.size == 0, "morphs.size != 0");
};

struct Points_ZV1_06_63_02 : Object_ZV1_06_63_02 {
    DynArray_Z<Vec3f> positions;
    std::assert(positions.size == 0, "positions.size != 0");

    DynArray_Z<TBVtx> tb_vertices;
    std::assert(tb_vertices.size == 0, "tb_vertices.size != 0");

    Morpher_Z morpher;
};

struct Vtx_Z {
    u16 uv_idx;
    u16 normal_idx;
    u16 color_idx;
    u16 vertices_idx;
};

struct Strip_Z {
    DynArray_Z<u16> strip_vertices_indices;
    Name_Z material_name;
    /// 1/2
    u32 tri_order;
};

struct StripExt_Z {
    DynArray_Z<Vtx_Z> vertices;
};

struct FaceCol_Z {
    i16 first_vertex_idx;
    i16 second_vertex_idx;
    i16 third_vertex_idx;
    i16 material_idx;
};

struct AABBNode_Z {
    Vec3f bb_min;
    i16 right_child_index_plus_one;
    i16 left_child_index_plus_one;
    Vec3f bb_max;
    RangeBeginSize collision_faces_range;
};

struct AABBCol_Z {
    DynArray_Z<FaceCol_Z> face_cols;
    DynArray_Z<AABBNode_Z> aabb_nodes;
};

using Vec3f_S16_Z = Vec<NumeratorFloat<i16, 1024>, 3>;

struct Mesh_ZV1_06_63_02 : Points_ZV1_06_63_02 {
    std::assert(type == ObjectType::Mesh_Z, "type != ObjectType::Mesh_Z");

    DynArray_Z<Vec2f> texcoords;
    std::assert(texcoords.size == 0, "texcoords.size != 0");

    DynArray_Z<Vec3f> normals;
    std::assert(normals.size == 0, "normals.size != 0");

    DynArray_Z<Strip_Z> strips;
    std::assert(strips.size == 0, "strips.size != 0");

    if (flags.FL_OBJECT_SKINNED)
    {
        Name_Z strip_override_material_names[strips.size];
    }

    DynArray_Z<StripExt_Z> strip_exts;
    std::assert(strip_exts.size == 0, "strip_exts.size != 0");

    DynArray_Z<Name_Z> material_names;

    f32 drawing_start_distance;
    f32 drawing_cutoff_distance;
    u32 shadow_related;
    u32 unknown0;
    u32 unknown1;
    u32 unknown2;

    DynArray_Z<SphereCol_Z> sphere_cols;
    DynArray_Z<BoxCol_Z> box_cols;
    DynArray_Z<CylindreCol_Z> cylindre_cols;

    AABBCol_Z aabb_col;
    DynArray_Z<Vec3f_S16_Z> aabb_col_vertices;
};

enum VertexLayout : u16 {
    VertexLayoutNoBlend = 0,
    VertexLayoutVolume = 1,
    VertexLayoutSkin1Blend = 2,
    VertexLayoutSkinVolume = 3,
    VertexLayoutSkin4Blend = 4,
    VertexLayoutMorph1Blend = 5,
    VertexLayoutMorph4Blend = 6,
};

enum D3DPRIMITIVETYPE : u16 {
    D3DPT_POINTLIST = 1,
    D3DPT_LINELIST = 2,
    D3DPT_LINESTRIP = 3,
    D3DPT_TRIANGLELIST = 4,
    D3DPT_TRIANGLESTRIP = 5,
    D3DPT_TRIANGLEFAN = 6,
};

struct VertexBufferExt_Z {
    u16 vertex_count;
    u16 vertex_stride;
    u64 vertices_addr = $ [[hidden]];
    u8 raw_vertices[vertex_count * vertex_stride];
};

struct IndexBufferExt_Z {
    u16 index_count;
    u64 indices_addr = $ [[hidden]];
    u16 data[index_count];
};

using VertexVectorComponent = u8 [[format("format_vertex_vector_component"), transform("format_vertex_vector_component")]];

fn format_vertex_vector_component(u8 vvc) {
    return (vvc / 255.0) * 2 - 1;
};

using VertexVector3u8 = Vec<VertexVectorComponent, 3>;

using VertexBlendIndex = f32 [[format("format_vertex_blend_index")]];

fn format_vertex_blend_index(f32 vbi) {
    return std::format("{} ({})", u32(vbi / 6.0), vbi);
};

using VertexBlendIndexU8 = u8 [[format("format_vertex_blend_index_u8")]];

fn format_vertex_blend_index_u8(u8 vbi) {
    return std::format("{} ({})", u32(vbi / 6), vbi);
};

using VertexUVComponent = i16 [[format("format_short2n_component")]];

fn format_short2n_component(i16 v) {
    if (v == -32768)
        return -1.0;

    return v / 32767.0;
};

using VertexUVShort2N = Vec<VertexUVComponent, 2>;

using VertexBlendWeightU8 = u8 [[format("format_vertex_blend_weight_u8")]];

fn format_vertex_blend_weight_u8(u8 w) {
    return std::format("{} ({})", w / 256.0, w);
};

struct VertexLayoutNoBlend {
    Vec3f position;
    VertexVector3u8 tangent;
    std::assert(is_normalized_or_zero(tangent), "VertexLayoutNoBlend !is_normalized_or_zero(tangent)");
    VertexVectorComponent tangent_w;
    VertexVector3u8 normal;
    std::assert(is_normalized_or_zero(normal), "VertexLayoutNoBlend !is_normalized_or_zero(normal)");
    VertexVectorComponent normal_w;
    Vec2f uv;
    Vec2f lightmap_uv;
};

struct VertexLayoutVolume {
    Vec3f position;
    Vec3f normal;
    std::assert(is_normalized_or_zero(normal), "VertexLayoutVolume !is_normalized_or_zero(normal)");
};

struct VertexLayoutSkin1Blend {
    Vec3f position;
    VertexVector3u8 tangent;
    std::assert(is_normalized_or_zero(tangent), "VertexLayoutSkin1Blend !is_normalized_or_zero(tangent)");
    VertexVectorComponent tangent_w;
    VertexVector3u8 normal;
    std::assert(is_normalized_or_zero(normal), "VertexLayoutSkin1Blend !is_normalized_or_zero(normal)");
    VertexVectorComponent normal_w;
    Vec2f uv;
    VertexBlendIndex blend_index;
    i32 pad2[3] [[hidden]];
    f32 blend_weight;
    std::assert(blend_weight == 0 || blend_weight == 1, "VertexLayoutSkin1Blend blend_weight != 0,1");
};

struct VertexLayoutSkinVolume {
    Vec3f position0;
    Vec3f position1;
    Vec3f position2;
    VertexBlendIndex blend_indices[3];
};

struct VertexLayoutSkin4Blend {
    Vec3f position;
    VertexVector3u8 tangent;
    std::assert(is_normalized_or_zero(tangent), "VertexLayoutSkin4Blend !is_normalized_or_zero(tangent)");
    VertexVectorComponent tangent_w;
    VertexVector3u8 normal;
    std::assert(is_normalized_or_zero(normal), "VertexLayoutSkin4Blend !is_normalized_or_zero(normal)");
    VertexVectorComponent normal_w;
    Vec2f uv;
    VertexBlendIndex blend_indices[4];
    f32 blend_weights[4];
};

struct VertexLayoutMorph1Blend {
    Vec3f position;
    VertexVector3u8 tangent;
    std::assert(is_normalized_or_zero(tangent), "VertexLayoutMorph1Blend !is_normalized_or_zero(tangent)");
    VertexVectorComponent tangent_w;
    VertexVector3u8 normal;
    std::assert(is_normalized_or_zero(normal), "VertexLayoutMorph1Blend !is_normalized_or_zero(normal)");
    VertexVectorComponent normal_w;
    VertexUVShort2N uv;
    VertexBlendIndexU8 blend_index;
    u8 pad[3] [[hidden]];
    f32 blend_weight;
    std::assert(blend_weight == 0 || blend_weight == 1, "VertexLayoutMorph1Blend blend_weight != 0,1");
};

struct VertexLayoutMorph4Blend {
    Vec3f position;
    VertexVector3u8 tangent;
    std::assert(is_normalized_or_zero(tangent), "VertexLayoutMorph4Blend !is_normalized_or_zero(tangent)");
    VertexVectorComponent tangent_w;
    VertexVector3u8 normal;
    std::assert(is_normalized_or_zero(normal), "VertexLayoutMorph4Blend !is_normalized_or_zero(normal)");
    VertexVectorComponent normal_w;
    VertexUVShort2N uv;
    VertexBlendIndexU8 blend_indices[4];
    VertexBlendWeightU8 blend_weights[4];
};

struct PrimitiveInfo_Z {
    u32 vertex_buffer_index;
    u32 index_buffer_index;
    u32 obj_constant_placeholder_ptr;

    D3DPRIMITIVETYPE primitive_type;
    std::assert(std::core::is_valid_enum(primitive_type), "Invalid primitive_type");
    std::assert(primitive_type == D3DPRIMITIVETYPE::D3DPT_TRIANGLELIST, "Primitive type is not triangle list");

    VertexLayout vertex_layout;
    std::assert(std::core::is_valid_enum(vertex_layout), "Invalid vertex_layout");
    std::assert(vertex_layout != VertexLayout::VertexLayoutMorph1Blend, "VertexLayoutMorph1Blend is being used");
    std::assert(vertex_layout != VertexLayout::VertexLayoutMorph4Blend, "VertexLayoutMorph4Blend is being used");
    if (parent.parent.parent.flags.FL_OBJECT_SKINNED) {
        if (parent.parent.parent.flags.FL_OBJECT_SHADOW_VOLUME) {
            std::assert(vertex_layout == VertexLayout::VertexLayoutSkinVolume, "Skinned shadow volume must use VertexLayoutSkinVolume");
        } else {
            std::assert(vertex_layout == VertexLayout::VertexLayoutSkin1Blend || vertex_layout == VertexLayout::VertexLayoutSkin4Blend, "Skinned mesh must use VertexLayoutSkin1Blend or VertexLayoutSkin4Blend");
        }
    } else if (parent.parent.parent.flags.FL_OBJECT_SHADOW_VOLUME) {
        std::assert(vertex_layout == VertexLayout::VertexLayoutVolume, "Non-skinned shadow volume must use VertexLayoutVolume");
    } else {
        std::assert(vertex_layout == VertexLayout::VertexLayoutNoBlend, "Non-skinned non-shadow mesh must use VertexLayoutNoBlend");
    }

    u16 cdcd;

    RangeBeginSize vertex_buffer_range;
    u16 index_buffer_index_begin;
    u32 face_count;

    u16 start_vertex;
    u16 vertex_stride;
    u32 cdcdcdcd;

    std::assert(vertex_buffer_index < parent.parent.vertex_buffers.size,
        "primitive references invalid vertex buffer");

    std::assert(index_buffer_index < parent.parent.index_buffers.size,
        "primitive references invalid index buffer");

    std::assert(vertex_stride == parent.parent.vertex_buffers.data[vertex_buffer_index].vertex_stride,
        "primitive vertex stride does not match selected vertex buffer stride");

    std::assert(vertex_buffer_range.begin + vertex_buffer_range.size <=
        parent.parent.vertex_buffers.data[vertex_buffer_index].vertex_count,
        "primitive vertex range is outside selected vertex buffer");

    u32 vertex_count = vertex_buffer_range.size [[hidden]];
    u64 vertex_addr =
        parent.parent.vertex_buffers.data[vertex_buffer_index].vertices_addr +
        vertex_buffer_range.begin * vertex_stride [[hidden]];

    match (vertex_layout) {
        (VertexLayout::VertexLayoutNoBlend): {
            std::assert(vertex_stride == 36, "bad VertexLayoutNoBlend stride");
            VertexLayoutNoBlend vertices[vertex_count] @ vertex_addr;
        }

        (VertexLayout::VertexLayoutVolume): {
            std::assert(vertex_stride == 24, "bad VertexLayoutVolume stride");
            VertexLayoutVolume vertices[vertex_count] @ vertex_addr;
        }

        (VertexLayout::VertexLayoutSkin1Blend): {
            std::assert(vertex_stride == 48, "bad VertexLayoutSkin1Blend stride");
            VertexLayoutSkin1Blend vertices[vertex_count] @ vertex_addr;
        }

        (VertexLayout::VertexLayoutSkinVolume): {
            std::assert(vertex_stride == 48, "bad VertexLayoutSkinVolume stride");
            VertexLayoutSkinVolume vertices[vertex_count] @ vertex_addr;
        }

        (VertexLayout::VertexLayoutSkin4Blend): {
            std::assert(vertex_stride == 60, "bad VertexLayoutSkin4Blend stride");
            VertexLayoutSkin4Blend vertices[vertex_count] @ vertex_addr;
        }

        (VertexLayout::VertexLayoutMorph1Blend): {
            std::assert(vertex_stride == 32, "bad VertexLayoutMorph1Blend stride");
            VertexLayoutMorph1Blend vertices[vertex_count] @ vertex_addr;
        }

        (VertexLayout::VertexLayoutMorph4Blend): {
            std::assert(vertex_stride == 32, "bad VertexLayoutMorph4Blend stride");
            VertexLayoutMorph4Blend vertices[vertex_count] @ vertex_addr;
        }

        (_): {
            u8 vertices[vertex_count * vertex_stride] @ vertex_addr;
        }
    }

    // Assume primitive_type is always D3DPRIMITIVETYPE::D3DPT_TRIANGLELIST
    u32 index_count = face_count * 3;

    std::assert(index_buffer_index_begin + index_count <=
        parent.parent.index_buffers.data[index_buffer_index].index_count,
        "primitive index range is outside selected index buffer");

    u64 index_addr =
        parent.parent.index_buffers.data[index_buffer_index].indices_addr +
        index_buffer_index_begin * 2 [[hidden]];

    u16 indices[index_count] @ index_addr;
};

struct MeshBuffers_Z {
    DynArray_Z<VertexBufferExt_Z> vertex_buffers;
    DynArray_Z<IndexBufferExt_Z> index_buffers;
    DynArray_Z<PrimitiveInfo_Z> primitive_infos;
};

struct MeshPc_ZV1_06_63_02 : Mesh_ZV1_06_63_02 {
    DynArray_Z<u32> unknown3;
    std::assert(unknown3.size == 0, "unknown3.size != 0");

    DynArray_Z<u32> primitive_info_indices;
    MeshBuffers_Z mesh_buffers;
};

MeshPc_ZV1_06_63_02 mesh_z @ 0x0;

std::assert(std::mem::eof(), "Whole input not consumed");