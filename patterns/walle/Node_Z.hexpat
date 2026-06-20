#pragma MIME application/x-node-z

#include <zouna.hexpat>

struct ResourceObject_ZV1_06_63_02 : BaseObject_Z {
    Name_Z link_name;
    DynArray_Z<Name_Z> linked_resources;
};

struct Node_ZV1_06_63_02 : ResourceObject_ZV1_06_63_02 {
    /// Name of the parent Node_Z
    /// 0 if root Node_Z
    Name_Z parent_name;
    /// Name of the head child Node_Z
    /// 0 if leaf Node_Z
    Name_Z head_child_name;
    /// Name of the previous sibling
    /// 0 if head child Node_Z
    Name_Z prev_node_name;
    /// Name of the next sibling
    /// 0 if tail child Node_Z
    Name_Z next_node_name;
    Name_Z object_name;
    Name_Z user_define_name;
    Name_Z light_data_name;
    Name_Z radiosity_bitmap_name;
    /// Always? 0
    Name_Z unk_name;
    std::assert(unk_name == 0, "Expected unk_name to be 0");
    Mat4f inverse_world_transform;
    Mat3x4f rot_in_world_matrix;
    Mat3x4f inverse_rot_in_world_matrix;
    /// Normalized
    Quat rot_in_world;
    Vec3f translation;
    u32 flags;
    /// Normalized
    Quat rotation;
    f32 scale;
    f32 scale_in_world;
    /// The reciprocal of scale_in_world
    f32 inv_scale_in_world;
    u32 occluder_zone_id;
    RGBA color;
    Sphere_Z b_sphere_world;
    Rect<u16> display_seads_rect;
    Rect<u16> collide_seads_rect;
    Mat4f world_transform;
    u32 collide_seads_id;
    u32 display_seads_id;
    u16 world_id;
    f32 start;
    f32 end;
};

Node_ZV1_06_63_02 node_z @ 0x0;

std::assert(std::mem::eof(), "Whole input not consumed");
