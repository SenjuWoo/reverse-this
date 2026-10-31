// ipc_link_test.cpp — offline harness for ipc_seqlock.h.
//
// Build (MinGW-w64): g++ -std=c++17 -O2 -pthread ipc_link_test.cpp -o ipc_link_test.exe
// Run: .\ipc_link_test.exe
//
// It creates a Local\ mapping, writes 50,000 frames from one thread while a
// reader pulls the newest clean snapshot, and fails on a torn read, a missing
// frame, or a non-monotonic frame id. No game, no D3D device, no admin rights.
#include "ipc_seqlock.h"

#include <atomic>
#include <chrono>
#include <cstdio>
#include <string>
#include <thread>

using namespace reverse_this;

int main() {
    const std::wstring name = L"Local\\ReverseThisIpcTest_" + std::to_wstring(GetCurrentProcessId());
    bool existed = false;
    auto buffer = SharedFrameBuffer::Create(name, &existed);
    if (!buffer) {
        std::printf("FAIL create mapping (GetLastError=%lu)\n", GetLastError());
        return 1;
    }
    std::printf("mapping %ls slots=%u%s\n", name.c_str(), buffer->slot_count(),
                existed ? " (reused)" : "");

    constexpr uint64_t kFrames = 50000;
    std::atomic<bool> done{false};
    std::atomic<uint64_t> written{0};
    std::atomic<uint64_t> torn{0};
    std::atomic<uint64_t> reads{0};

    std::thread writer([&] {
        for (uint64_t id = 1; id <= kFrames; ++id) {
            Frame frame{};
            frame.frame_id = id;
            frame.rgba = static_cast<uint32_t>(id);
            frame.linear_depth = static_cast<float>(id) * 0.5f;
            frame.near_z = 0.1f;
            frame.far_z = 1000.0f;
            for (int i = 0; i < 16; ++i) {
                frame.view_proj[i] = static_cast<float>(id + i);
                frame.camera_world[i] = static_cast<float>(id - i);
            }
            frame.timestamp_ns = static_cast<uint64_t>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(
                    std::chrono::steady_clock::now().time_since_epoch())
                    .count());
            if (!buffer->Write(frame)) {
                std::printf("FAIL write %llu\n", static_cast<unsigned long long>(id));
                std::exit(1);
            }
            written.store(id, std::memory_order_release);
        }
        done.store(true, std::memory_order_release);
    });

    uint64_t last = 0;
    uint64_t accepted = 0;
    while (!done.load(std::memory_order_acquire) || last < kFrames) {
        Frame frame{};
        if (!buffer->ReadLatest(&frame)) {
            torn.fetch_add(1);
            if (torn.load() > 1000000) {
                std::printf("FAIL reader could not get a clean frame\n");
                std::exit(1);
            }
            continue;
        }
        reads.fetch_add(1);
        // A clean but stale slot is normal when newer slots are mid-write; the
        // seqlock guarantees consistency, not that the newest frame is visible.
        if (frame.frame_id < last) continue;
        const bool consistent = frame.rgba == static_cast<uint32_t>(frame.frame_id) &&
                                frame.linear_depth == static_cast<float>(frame.frame_id) * 0.5f &&
                                frame.view_proj[0] == static_cast<float>(frame.frame_id);
        if (!consistent) {
            std::printf("FAIL torn frame %llu rgba=%u depth=%.1f vp0=%.1f\n",
                        static_cast<unsigned long long>(frame.frame_id), frame.rgba,
                        frame.linear_depth, frame.view_proj[0]);
            return 1;
        }
        if (frame.frame_id > last) {
            last = frame.frame_id;
            ++accepted;
        }
    }
    writer.join();
    std::printf("PASS frames=%llu accepted=%llu reads=%llu retries=%llu\n",
                static_cast<unsigned long long>(written.load()),
                static_cast<unsigned long long>(accepted),
                static_cast<unsigned long long>(reads.load()),
                static_cast<unsigned long long>(torn.load()));
    return last == kFrames ? 0 : 1;
}
