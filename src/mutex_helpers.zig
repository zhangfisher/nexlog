const std = @import("std");

/// Helper functions for working with std.atomic.Mutex in Zig 0.16
/// Since std.atomic.Mutex only provides tryLock(), we need to implement blocking locks

pub fn lockMutex(m: *std.atomic.Mutex) void {
    while (!m.tryLock()) {
        // Spin wait - yield CPU to other threads
        std.atomic.spinLoopHint();
    }
}

pub fn unlockMutex(m: *std.atomic.Mutex) void {
    m.unlock();
}

/// Lock a mutex with automatic unlock (for use with defer)
pub fn lockMutexScoped(m: *std.atomic.Mutex) void {
    lockMutex(m);
}

/// Unlock a mutex (for manual unlock when not using defer)
pub fn unlockMutexScoped(m: *std.atomic.Mutex) void {
    unlockMutex(m);
}
