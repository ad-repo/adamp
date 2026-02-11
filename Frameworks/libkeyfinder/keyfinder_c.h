// C wrapper for libkeyfinder (C++ library)
// Provides a simple C API for Swift interop

#ifndef KEYFINDER_C_H
#define KEYFINDER_C_H

#ifdef __cplusplus
extern "C" {
#endif

// Key result values (matches KeyFinder::key_t)
typedef enum {
    KF_A_MAJOR = 0,
    KF_A_MINOR,
    KF_B_FLAT_MAJOR,
    KF_B_FLAT_MINOR,
    KF_B_MAJOR,
    KF_B_MINOR = 5,
    KF_C_MAJOR,
    KF_C_MINOR,
    KF_D_FLAT_MAJOR,
    KF_D_FLAT_MINOR,
    KF_D_MAJOR = 10,
    KF_D_MINOR,
    KF_E_FLAT_MAJOR,
    KF_E_FLAT_MINOR,
    KF_E_MAJOR,
    KF_E_MINOR = 15,
    KF_F_MAJOR,
    KF_F_MINOR,
    KF_G_FLAT_MAJOR,
    KF_G_FLAT_MINOR,
    KF_G_MAJOR = 20,
    KF_G_MINOR,
    KF_A_FLAT_MAJOR,
    KF_A_FLAT_MINOR,
    KF_SILENCE = 24
} kf_key_t;

// Opaque handle to a progressive analysis session
typedef struct kf_session kf_session_t;

// Create a new progressive analysis session
// frame_rate: audio sample rate (e.g. 44100)
// channels: number of audio channels (e.g. 1 for mono, 2 for stereo)
kf_session_t* kf_session_create(unsigned int frame_rate, unsigned int channels);

// Feed audio samples to the session for progressive analysis
// samples: interleaved audio samples as doubles
// sample_count: total number of samples (frames * channels)
void kf_session_feed(kf_session_t* session, const float* samples, unsigned int sample_count);

// Get the current progressive key estimate
kf_key_t kf_session_get_key(kf_session_t* session);

// Finalize the session (flush remaining audio) and get final key
kf_key_t kf_session_finalize(kf_session_t* session);

// Destroy a session and free resources
void kf_session_destroy(kf_session_t* session);

#ifdef __cplusplus
}
#endif

#endif // KEYFINDER_C_H
