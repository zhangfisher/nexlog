const std = @import("std");
const types = @import("../core/types.zig");
const mutex_helpers = @import("../mutex_helpers.zig");

const lockMutex = mutex_helpers.lockMutex;
const unlockMutex = mutex_helpers.unlockMutex;

/// Log entry for async processing
pub const LogEntry = struct {
    level: types.LogLevel,
    message: []const u8,
    metadata: ?types.LogMetadata,
    timestamp: i64,

    pub fn init(level: types.LogLevel, message: []const u8, metadata: ?types.LogMetadata) LogEntry {
        return LogEntry{
            .level = level,
            .message = message,
            .metadata = metadata,
            .timestamp = types.getCurrentTimestamp(),
        };
    }

    pub fn deinit(self: *LogEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
    }
};

/// Async-safe log queue with backpressure support
pub const AsyncLogQueue = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    queue: std.ArrayList(LogEntry),
    mutex: std.atomic.Mutex,
    // condition: std.Thread.Condition, // Removed in Zig 0.16, using simple spin wait instead
    max_size: usize,
    dropped_count: u64,
    is_closed: bool,

    pub fn init(allocator: std.mem.Allocator, max_size: usize) Self {
        return Self{
            .allocator = allocator,
            .queue = .empty,
            .mutex = std.atomic.Mutex.unlocked,
            .max_size = max_size,
            .dropped_count = 0,
            .is_closed = false,
        };
    }

    pub fn deinit(self: *Self) void {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        // Clean up remaining entries
        for (self.queue.items) |*entry| {
            entry.deinit(self.allocator);
        }
        self.queue.deinit(self.allocator);
        self.is_closed = true;
        // self.condition.broadcast(); // Removed in Zig 0.16, using simple spin wait instead
    }

    /// Push log entry to queue (non-blocking with backpressure)
    pub fn push(self: *Self, entry: LogEntry) !void {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        if (self.is_closed) {
            return error.QueueClosed;
        }

        // Handle backpressure
        if (self.queue.items.len >= self.max_size) {
            // Drop oldest entry to make room
            var old_entry = self.queue.orderedRemove(0);
            old_entry.deinit(self.allocator);
            self.dropped_count += 1;
        }

        // Clone the message to avoid lifetime issues
        const owned_message = try self.allocator.dupe(u8, entry.message);
        var owned_entry = entry;
        owned_entry.message = owned_message;

        try self.queue.append(self.allocator, owned_entry);
        // self.condition.signal(); // Removed in Zig 0.16, using simple spin wait
    }

    /// Pop log entry from queue (blocking)
    pub fn pop(self: *Self) !LogEntry {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        while (self.queue.items.len == 0 and !self.is_closed) {
            // In Zig 0.16, use simple spin wait instead of condition variable
            unlockMutex(&self.mutex);
            // Can't use std.Io.sleep without an Io instance, so use a small yield
            std.atomic.spinLoopHint();
            unlockMutex(&self.mutex);
            lockMutex(&self.mutex);
        }

        if (self.is_closed and self.queue.items.len == 0) {
            return error.QueueClosed;
        }

        return self.queue.orderedRemove(0);
    }

    /// Try to pop without blocking
    pub fn tryPop(self: *Self) ?LogEntry {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        if (self.queue.items.len > 0) {
            return self.queue.orderedRemove(0);
        }

        return null;
    }

    /// Get queue statistics
    pub fn getStats(self: *Self) QueueStats {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        return QueueStats{
            .queue_size = self.queue.items.len,
            .max_size = self.max_size,
            .dropped_count = self.dropped_count,
            .is_closed = self.is_closed,
        };
    }

    pub fn close(self: *Self) void {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        self.is_closed = true;
        // self.condition.broadcast(); // Removed in Zig 0.16, using simple spin wait instead
    }
};

pub const QueueStats = struct {
    queue_size: usize,
    max_size: usize,
    dropped_count: u64,
    is_closed: bool,
};

/// Async log processor that runs in background
pub const AsyncLogProcessor = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    queue: *AsyncLogQueue,
    handlers: std.ArrayList(*AsyncLogHandler),
    thread: ?std.Thread,
    should_stop: std.atomic.Value(bool),
    stats: ProcessorStats,
    mutex: std.atomic.Mutex,

    pub fn init(allocator: std.mem.Allocator, queue: *AsyncLogQueue) Self {
        return Self{
            .allocator = allocator,
            .queue = queue,
            .handlers = .empty,
            .thread = null,
            .should_stop = std.atomic.Value(bool).init(false),
            .stats = ProcessorStats{},
            .mutex = std.atomic.Mutex.unlocked,
        };
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        self.handlers.deinit(self.allocator);
    }

    pub fn addHandler(self: *Self, handler: *AsyncLogHandler) !void {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        try self.handlers.append(self.allocator, handler);
    }

    pub fn start(self: *Self) !void {
        if (self.thread != null) {
            return error.AlreadyStarted;
        }

        self.should_stop.store(false, .monotonic);
        self.thread = try std.Thread.spawn(.{}, processLoop, .{self});
    }

    pub fn stop(self: *Self) void {
        if (self.thread) |thread| {
            self.should_stop.store(true, .monotonic);
            self.queue.close();
            thread.join();
            self.thread = null;
        }
    }

    fn processLoop(self: *Self) void {
        while (!self.should_stop.load(.monotonic)) {
            if (self.queue.pop()) |entry| {
                self.processEntry(entry) catch |err| {
                    self.updateStats(.{ .errors = 1 });
                    // Log error to stderr as fallback
                    std.debug.print("Async log processing error: {}\n", .{err});
                };
            } else |err| {
                if (err == error.QueueClosed) {
                    break;
                }
            }
        }

        // Process remaining entries
        while (self.queue.tryPop()) |entry| {
            self.processEntry(entry) catch {};
        }
    }

    fn processEntry(self: *Self, entry: LogEntry) !void {
        defer {
            var mutable_entry = entry;
            mutable_entry.deinit(self.allocator);
        }

        lockMutex(&self.mutex);
        const handlers_copy = self.handlers.items;
        unlockMutex(&self.mutex);

        for (handlers_copy) |handler| {
            handler.logAsync(entry) catch {
                self.updateStats(.{ .handler_errors = 1 });
                continue;
            };
        }

        self.updateStats(.{ .processed = 1 });
    }

    fn updateStats(self: *Self, delta: ProcessorStats) void {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        self.stats.processed += delta.processed;
        self.stats.errors += delta.errors;
        self.stats.handler_errors += delta.handler_errors;
    }

    pub fn getStats(self: *Self) ProcessorStats {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        return self.stats;
    }
};

pub const ProcessorStats = struct {
    processed: u64 = 0,
    errors: u64 = 0,
    handler_errors: u64 = 0,
};

/// Interface for async log handlers
pub const AsyncLogHandler = struct {
    const Self = @This();

    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        logAsync: *const fn (ptr: *anyopaque, entry: LogEntry) anyerror!void,
        flushAsync: *const fn (ptr: *anyopaque) anyerror!void,
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub fn init(
        pointer: anytype,
        comptime logAsyncFn: fn (ptr: @TypeOf(pointer), entry: LogEntry) anyerror!void,
        comptime flushAsyncFn: fn (ptr: @TypeOf(pointer)) anyerror!void,
        comptime deinitFn: fn (ptr: @TypeOf(pointer)) void,
    ) Self {
        const Ptr = @TypeOf(pointer);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .pointer) @compileError("Expected pointer type");
        if (ptr_info.pointer.size != .one) @compileError("Expected single item pointer");

        const gen = struct {
            fn logAsyncImpl(ptr: *anyopaque, entry: LogEntry) anyerror!void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                return @call(.always_inline, logAsyncFn, .{ self, entry });
            }

            fn flushAsyncImpl(ptr: *anyopaque) anyerror!void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                return @call(.always_inline, flushAsyncFn, .{self});
            }

            fn deinitImpl(ptr: *anyopaque) void {
                const self: Ptr = @ptrCast(@alignCast(ptr));
                return @call(.always_inline, deinitFn, .{self});
            }

            const vtable = VTable{
                .logAsync = logAsyncImpl,
                .flushAsync = flushAsyncImpl,
                .deinit = deinitImpl,
            };
        };

        return Self{
            .ptr = pointer,
            .vtable = &gen.vtable,
        };
    }

    pub fn logAsync(self: Self, entry: LogEntry) !void {
        return self.vtable.logAsync(self.ptr, entry);
    }

    pub fn flushAsync(self: Self) !void {
        return self.vtable.flushAsync(self.ptr);
    }

    pub fn deinit(self: Self) void {
        return self.vtable.deinit(self.ptr);
    }
};
