const std = @import("std");
const types = @import("../core/types.zig");
const config = @import("../core/config.zig");
const async_core = @import("core.zig");

/// Async logger that provides non-blocking logging operations
pub const AsyncLogger = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: AsyncLogConfig,
    queue: async_core.AsyncLogQueue,
    processor: async_core.AsyncLogProcessor,
    is_started: bool,

    pub fn init(allocator: std.mem.Allocator, cfg: AsyncLogConfig) !*Self {
        var logger = try allocator.create(Self);

        logger.* = Self{
            .allocator = allocator,
            .config = cfg,
            .queue = async_core.AsyncLogQueue.init(allocator, cfg.queue_size),
            .processor = async_core.AsyncLogProcessor.init(allocator, &logger.queue),
            .is_started = false,
        };

        return logger;
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        self.processor.deinit();
        self.queue.deinit();
        self.allocator.destroy(self);
    }

    pub fn start(self: *Self) !void {
        if (self.is_started) {
            return error.AlreadyStarted;
        }

        try self.processor.start();
        self.is_started = true;
    }

    pub fn stop(self: *Self) void {
        if (self.is_started) {
            self.processor.stop();
            self.is_started = false;
        }
    }

    pub fn addHandler(self: *Self, handler: *async_core.AsyncLogHandler) !void {
        return self.processor.addHandler(handler);
    }

    /// Non-blocking async log operation
    pub fn logAsync(
        self: *Self,
        level: types.LogLevel,
        comptime fmt: []const u8,
        args: anytype,
        metadata: ?types.LogMetadata,
    ) !void {
        if (@intFromEnum(level) < @intFromEnum(self.config.min_level)) {
            return;
        }

        if (!self.is_started) {
            return error.LoggerNotStarted;
        }

        // Format message
        var temp_buffer: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&temp_buffer);
        const message = try std.fmt.allocPrint(fba.allocator(), fmt, args);

        const entry = async_core.LogEntry.init(level, message, metadata);
        try self.queue.push(entry);
    }

    /// Convenience async methods
    pub fn traceAsync(self: *Self, comptime fmt: []const u8, args: anytype, metadata: ?types.LogMetadata) !void {
        return self.logAsync(.trace, fmt, args, metadata);
    }

    pub fn debugAsync(self: *Self, comptime fmt: []const u8, args: anytype, metadata: ?types.LogMetadata) !void {
        return self.logAsync(.debug, fmt, args, metadata);
    }

    pub fn infoAsync(self: *Self, comptime fmt: []const u8, args: anytype, metadata: ?types.LogMetadata) !void {
        return self.logAsync(.info, fmt, args, metadata);
    }

    pub fn warnAsync(self: *Self, comptime fmt: []const u8, args: anytype, metadata: ?types.LogMetadata) !void {
        return self.logAsync(.warn, fmt, args, metadata);
    }

    pub fn errAsync(self: *Self, comptime fmt: []const u8, args: anytype, metadata: ?types.LogMetadata) !void {
        return self.logAsync(.err, fmt, args, metadata);
    }

    pub fn criticalAsync(self: *Self, comptime fmt: []const u8, args: anytype, metadata: ?types.LogMetadata) !void {
        return self.logAsync(.critical, fmt, args, metadata);
    }

    /// Async flush - signals all handlers to flush their buffers
    pub fn flushAsync(self: *Self) !void {
        // Create a special flush entry
        const flush_entry = async_core.LogEntry{
            .level = .trace, // Use trace level for flush signals
            .message = "__FLUSH__",
            .metadata = null,
            .timestamp =types.getCurrentTimestamp(),
        };

        try self.queue.push(flush_entry);
    }

    /// Get comprehensive async logger statistics
    pub fn getStats(self: *Self) AsyncLoggerStats {
        const queue_stats = self.queue.getStats();
        const processor_stats = self.processor.getStats();

        return AsyncLoggerStats{
            .queue_size = queue_stats.queue_size,
            .max_queue_size = queue_stats.max_size,
            .dropped_logs = queue_stats.dropped_count,
            .processed_logs = processor_stats.processed,
            .processing_errors = processor_stats.errors,
            .handler_errors = processor_stats.handler_errors,
            .is_started = self.is_started,
            .queue_is_closed = queue_stats.is_closed,
        };
    }

    /// Wait for all queued logs to be processed (for graceful shutdown)
    pub fn drain(self: *Self, timeout_ms: u64) !void {
        // In Zig 0.16, use Io.Clock.now instead of std.time.milliTimestamp
        var io_threaded: std.Io.Threaded = .init_single_threaded;
        const io = io_threaded.io();
        const start_time = @divTrunc(std.Io.Clock.now(.real, io).nanoseconds, 1_000_000); // Convert to ms

        while (true) {
            const stats = self.getStats();
            if (stats.queue_size == 0) {
                return;
            }

            const current_time_ns = std.Io.Clock.now(.real, io).nanoseconds;
            const current_time = @divTrunc(current_time_ns, 1_000_000);
            const elapsed = current_time - start_time;
            if (elapsed > timeout_ms) {
                return error.DrainTimeout;
            }

            std.Io.sleep(io, .{ .nanoseconds = 1_000_000 }, .real) catch {}; // Sleep 1ms
        }
    }
};

pub const AsyncLogConfig = struct {
    min_level: types.LogLevel = .info,
    queue_size: usize = 10000,
    enable_backpressure: bool = true,
    flush_interval_ms: u64 = 5000,
};

pub const AsyncLoggerStats = struct {
    queue_size: usize,
    max_queue_size: usize,
    dropped_logs: u64,
    processed_logs: u64,
    processing_errors: u64,
    handler_errors: u64,
    is_started: bool,
    queue_is_closed: bool,
};
