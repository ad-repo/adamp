// C wrapper implementation for libkeyfinder
#include "keyfinder_c.h"
#include <keyfinder/keyfinder.h>
#include <keyfinder/audiodata.h>
#include <keyfinder/workspace.h>

struct kf_session {
    KeyFinder::KeyFinder finder;
    KeyFinder::Workspace workspace;
    unsigned int frameRate;
    unsigned int channels;
    // Buffer to accumulate samples before feeding to keyfinder
    // progressiveChromagram expects a meaningful chunk of audio
    static const unsigned int CHUNK_FRAMES = 16384;
    std::vector<double> sampleBuffer;
    unsigned int bufferedFrames;
    bool hasData;
};

extern "C" {

kf_session_t* kf_session_create(unsigned int frame_rate, unsigned int channels) {
    kf_session_t* session = new kf_session_t();
    session->frameRate = frame_rate;
    session->channels = channels;
    session->bufferedFrames = 0;
    session->hasData = false;
    session->sampleBuffer.reserve(kf_session::CHUNK_FRAMES * channels);
    return session;
}

void kf_session_feed(kf_session_t* session, const float* samples, unsigned int sample_count) {
    if (!session || !samples || sample_count == 0) return;

    unsigned int channels = session->channels;
    unsigned int frames = sample_count; // sample_count is mono frame count

    // Append to buffer (convert float to double)
    for (unsigned int i = 0; i < frames; i++) {
        session->sampleBuffer.push_back(static_cast<double>(samples[i]));
    }
    session->bufferedFrames += frames;

    // When we have enough frames, feed to keyfinder
    while (session->bufferedFrames >= kf_session::CHUNK_FRAMES) {
        unsigned int chunkSamples = kf_session::CHUNK_FRAMES * channels;

        KeyFinder::AudioData audio;
        audio.setFrameRate(session->frameRate);
        audio.setChannels(channels);
        audio.addToSampleCount(chunkSamples);

        for (unsigned int i = 0; i < chunkSamples; i++) {
            audio.setSample(i, session->sampleBuffer[i]);
        }

        try {
            session->finder.progressiveChromagram(audio, session->workspace);
            session->hasData = true;
        } catch (...) {
            // Silently ignore errors
        }

        // Remove consumed samples
        session->sampleBuffer.erase(
            session->sampleBuffer.begin(),
            session->sampleBuffer.begin() + chunkSamples
        );
        session->bufferedFrames -= kf_session::CHUNK_FRAMES;
    }
}

kf_key_t kf_session_get_key(kf_session_t* session) {
    if (!session || !session->hasData) return KF_SILENCE;
    try {
        KeyFinder::key_t key = session->finder.keyOfChromagram(session->workspace);
        return static_cast<kf_key_t>(key);
    } catch (...) {
        return KF_SILENCE;
    }
}

kf_key_t kf_session_finalize(kf_session_t* session) {
    if (!session) return KF_SILENCE;

    // Feed any remaining buffered audio
    if (session->bufferedFrames > 0) {
        unsigned int channels = session->channels;
        unsigned int chunkSamples = session->bufferedFrames * channels;

        KeyFinder::AudioData audio;
        audio.setFrameRate(session->frameRate);
        audio.setChannels(channels);
        audio.addToSampleCount(chunkSamples);

        for (unsigned int i = 0; i < chunkSamples; i++) {
            audio.setSample(i, session->sampleBuffer[i]);
        }

        try {
            session->finder.progressiveChromagram(audio, session->workspace);
            session->hasData = true;
        } catch (...) {}

        session->sampleBuffer.clear();
        session->bufferedFrames = 0;
    }

    try {
        session->finder.finalChromagram(session->workspace);
        KeyFinder::key_t key = session->finder.keyOfChromagram(session->workspace);
        return static_cast<kf_key_t>(key);
    } catch (...) {
        return KF_SILENCE;
    }
}

void kf_session_destroy(kf_session_t* session) {
    delete session;
}

} // extern "C"
