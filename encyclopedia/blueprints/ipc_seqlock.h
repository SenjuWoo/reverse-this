// ipc_seqlock.h — single-header C++17 named shared memory for one frame header.
//
// Why: a passthrough renderer needs the guest's latest camera pose, linear depth
// and a representative RGBA value without blocking the host render thread. A
// seqlock gives a consistent snapshot without a mutex: the writer bumps an odd
// sequence before the payload and an even one after; the reader retries if the
// sequence changed or is odd. This file stores the header only (160 bytes per
// slot), not a full image. Put large pixel buffers in a separate mapping and
// send their slot id/handle in this header.
//
// Layout is fixed and asserted; keep ipc_seqlock.py in sync if you change it.
#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <atomic>
#include <cstdint>
#include <cstring>
#include <memory>
#include <string>
#include <type_traits>

namespace reverse_this {

constexpr uint32_t kIpcMagic = 0x50544652;  // 'RTFP' little-endian
constexpr uint32_t kIpcVersion = 1;
constexpr uint32_t kSlotCount = 3;

struct Frame {
    uint32_t rgba;          // 0xAABBGGRR, guest center/reference pixel
    float linear_depth;     // guest linear depth in meters
    float near_z;           // guest near plane
    float far_z;            // guest far plane
    float view_proj[16];    // guest camera view-projection, row-major
    float camera_world[16]; // guest camera world transform, row-major
    uint64_t frame_id;
    uint64_t timestamp_ns;
};

struct Slot {
    std::atomic<uint32_t> seq;  // even = stable, odd = write in progress
    uint32_t pad;               // keeps Frame 8-byte aligned
    Frame frame;
};

struct Shared {
    uint32_t magic;
    uint32_t version;
    uint32_t slot_count;
    uint32_t reserved;
    Slot slots[kSlotCount];
};

static_assert(std::is_trivially_copyable<Frame>::value, "Frame must be trivially copyable");
static_assert(std::atomic<uint32_t>::is_always_lock_free, "uint32_t atomics must be lock-free");
static_assert(sizeof(Frame) == 160, "Frame layout changed; update ipc_seqlock.py");
static_assert(sizeof(Slot) == 168, "Slot layout changed; update ipc_seqlock.py");
static_assert(sizeof(Shared) == 520, "Shared layout changed; update ipc_seqlock.py");

// Owns one named mapping. Create() is for the producer; Open() is for a reader.
class SharedFrameBuffer {
public:
    static std::unique_ptr<SharedFrameBuffer> Create(const std::wstring& name,
                                                     bool* already_exists = nullptr) {
        auto self = std::unique_ptr<SharedFrameBuffer>(new SharedFrameBuffer());
        self->name_ = name;
        self->mapping_ = CreateFileMappingW(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, 0,
                                            static_cast<DWORD>(sizeof(Shared)), name.c_str());
        if (!self->mapping_) return nullptr;
        if (already_exists) *already_exists = (GetLastError() == ERROR_ALREADY_EXISTS);
        self->view_ = static_cast<Shared*>(MapViewOfFile(self->mapping_, FILE_MAP_ALL_ACCESS, 0, 0,
                                                         sizeof(Shared)));
        if (!self->view_) return nullptr;
        if (!*already_exists) {
            std::memset(self->view_, 0, sizeof(Shared));
            self->view_->magic = kIpcMagic;
            self->view_->version = kIpcVersion;
            self->view_->slot_count = kSlotCount;
        }
        if (self->view_->magic != kIpcMagic || self->view_->version != kIpcVersion ||
            self->view_->slot_count != kSlotCount) {
            return nullptr;  // incompatible producer
        }
        return self;
    }

    static std::unique_ptr<SharedFrameBuffer> Open(const std::wstring& name) {
        auto self = std::unique_ptr<SharedFrameBuffer>(new SharedFrameBuffer());
        self->name_ = name;
        self->mapping_ = OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE, name.c_str());
        if (!self->mapping_) return nullptr;
        self->view_ = static_cast<Shared*>(MapViewOfFile(self->mapping_, FILE_MAP_ALL_ACCESS, 0, 0,
                                                         sizeof(Shared)));
        if (!self->view_ || self->view_->magic != kIpcMagic ||
            self->view_->version != kIpcVersion || self->view_->slot_count != kSlotCount) {
            return nullptr;
        }
        return self;
    }

    ~SharedFrameBuffer() {
        if (view_) UnmapViewOfFile(view_);
        if (mapping_) CloseHandle(mapping_);
    }

    SharedFrameBuffer(const SharedFrameBuffer&) = delete;
    SharedFrameBuffer& operator=(const SharedFrameBuffer&) = delete;

    // Writer: one producer only. Returns false if the slot is being read? No:
    // seqlock writers never wait for readers; they just invalidate the slot.
    bool Write(const Frame& frame) {
        if (!view_ || view_->slot_count == 0) return false;
        Slot& slot = view_->slots[frame.frame_id % view_->slot_count];
        uint32_t s = slot.seq.load(std::memory_order_relaxed);
        slot.seq.store(s + 1, std::memory_order_relaxed);  // odd: write in progress
        std::atomic_thread_fence(std::memory_order_release);
        slot.frame = frame;
        std::atomic_thread_fence(std::memory_order_release);
        slot.seq.store(s + 2, std::memory_order_relaxed);  // even: stable
        return true;
    }

    // Reader: retries a bounded number of times, then reports a torn read.
    bool ReadSlot(uint32_t index, Frame* out, int retries = 8) const {
        if (!view_ || !out || index >= view_->slot_count) return false;
        const Slot& slot = view_->slots[index];
        for (int attempt = 0; attempt < retries; ++attempt) {
            uint32_t s1 = slot.seq.load(std::memory_order_acquire);
            if (s1 & 1u) continue;
            Frame copy = slot.frame;
            std::atomic_thread_fence(std::memory_order_acquire);
            uint32_t s2 = slot.seq.load(std::memory_order_relaxed);
            if (s1 == s2) {
                *out = copy;
                return true;
            }
        }
        return false;
    }

    // Reader: newest slot by frame_id among the slots that read cleanly.
    bool ReadLatest(Frame* out) const {
        if (!view_ || !out) return false;
        bool have = false;
        Frame best{};
        for (uint32_t i = 0; i < view_->slot_count; ++i) {
            Frame candidate{};
            if (!ReadSlot(i, &candidate)) continue;
            if (!have || candidate.frame_id > best.frame_id) {
                best = candidate;
                have = true;
            }
        }
        if (have) *out = best;
        return have;
    }

    uint32_t slot_count() const { return view_ ? view_->slot_count : 0; }

private:
    SharedFrameBuffer() = default;
    HANDLE mapping_ = nullptr;
    Shared* view_ = nullptr;
    std::wstring name_;
};

}  // namespace reverse_this
