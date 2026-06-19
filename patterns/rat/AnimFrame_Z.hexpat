#pragma MIME application/x-mesh-z

#include <zouna.hexpat>

bitfield AnimFramePlayFlags {
    FL_ANIM_PLAY : 1;
    FL_ANIM_STARTED : 1;
    FL_ANIM_READMESSAGE : 1;
    FL_ANIM_PLAYONCE : 1;
    FL_ANIM_NEVERAGAIN : 1;
    FL_ANIM_PLAYED : 1;
    FL_ANIM_AUTOSTART : 1;
    FL_ANIM_MESSAGE : 1;
    FL_ANIM_PAUSED : 1;
    FL_ANIM_UNK_0x200 : 1;
};

struct KeyFollow_Z {
    Name_Z node_name;
    Vec3f axis;
    float avance;
    u32 orient;
};

using KeyframerFollow_Z = KeyframerNoFlagsTpl_Z<KeyFollow_Z>;

struct StartStop_Z {
    Name_Z anim_frame_name; // anim frame to start/stop
    u32 value;              // value (stop = 0 / start = 1 )
};

struct KeyStartStop_Z {
    u32 start_stop_count;
    f32 time;
    StartStop_Z start_stops[start_stop_count];
};

using KeyframerStartStop_Z = KeyframerNoFlagsTpl_Z<KeyStartStop_Z>;

struct ResourceObject_ZV1_06_63_02 : BaseObject_Z {
    Name_Z link_name;
    DynArray_Z<Name_Z> linked_resources;
};

struct AnimFrame_ZV1_06_63_02 : ResourceObject_ZV1_06_63_02 {
    Name_Z node_name;
    std::assert(node_name, "Node name must be specified");
    float duration;
    std::assert(duration > 0, "Duration must be positive");
    KeyframerVec3f_Z translation_keyframer;
    KeyframerRot_Z rot_keyframer;
    KeyframerVec3fComp_Z scale_keyframer;
    KeyframerFloatComp_Z time_keyframer; // used to update follow_keyframer
    KeyframerVec3fLinear_Z color_keyframer; // for hfog/light/omni
    KeyframerVec3fLinear_Z ambient_keyframer; // for light
    KeyframerMessage_Z msg_keyframer;
    KeyframerFollow_Z follow_keyframer;
    KeyframerStartStop_Z start_stop_keyframer; // start and stop other anim frames
    float cur_time;
    std::assert(cur_time == 0, "Current time must be zero");
    float start_time;
    std::assert(start_time == 0, "Start time must be zero");
    float prev_time;
    std::assert(prev_time == 0, "Previous time must be zero");
    AnimFramePlayFlags play_flags;
};

AnimFrame_ZV1_06_63_02 animframe_z @ 0x0;

std::assert(std::mem::eof(), "Whole input not consumed");