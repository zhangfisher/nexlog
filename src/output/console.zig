const std = @import("std");
const types = @import("../core/types.zig");
const handlers = @import("handlers.zig");

pub const ConsoleConfig = struct {
    enable_colors: bool = true,
    min_level: types.LogLevel = .debug,
    use_stderr: bool = true,
    buffer_size: usize = 4096,

    show_source_location: bool = true,
    show_function: bool = false,
    show_thread_id: bool = false,

    /// Use fast path optimization for high-performance logging
    /// Disables some formatting features but significantly faster
    fast_mode: bool = false,
};

pub const ConsoleHandler = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: ConsoleConfig,

    pub fn init(allocator: std.mem.Allocator, config: ConsoleConfig) !*Self {
        const handler = try allocator.create(Self);
        handler.* = .{
            .allocator = allocator,
            .config = config,
        };
        return handler;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn log(
        self: *Self,
        level: types.LogLevel,
        message: []const u8,
        metadata: ?types.LogMetadata,
    ) !void {
        if (@intFromEnum(level) < @intFromEnum(self.config.min_level)) {
            return;
        }

        // Ultra-fast mode: minimal formatting for maximum throughput
        if (self.config.fast_mode) {
            const timestamp = if (metadata) |m| m.timestamp else types.getCurrentTimestamp();
            // For Zig 0.16, use simple debug print for fast mode
            std.debug.print("[{d}] {s}\n", .{ timestamp, message });
            return;
        }

        // For Zig 0.16, simplify console output to avoid complex IO API issues
        // Just use debug print for now
        const timestamp = if (metadata) |m| m.timestamp else types.getCurrentTimestamp();

        if (self.config.enable_colors) {
            std.debug.print("{s}[{d}] [{s}]\x1b[0m {s}\n", .{
                level.toColor(),
                timestamp,
                level.toString(),
                message,
            });
        } else {
            std.debug.print("[{d}] [{s}] {s}\n", .{
                timestamp,
                level.toString(),
                message,
            });
        }
    }

    pub fn flush(self: *Self) !void {
        // Console output is immediately flushed, so this is a no-op
        _ = self;
    }

    /// Convert to generic LogHandler interface
    pub fn toLogHandler(self: *Self) handlers.LogHandler {
        return handlers.LogHandler.init(
            self,
            .console,
            ConsoleHandler.log,
            ConsoleHandler.writeFormattedLog,
            ConsoleHandler.flush,
            ConsoleHandler.deinit,
        );
    }

    pub fn writeFormattedLog(self: *Self, formatted_message: []const u8) !void {
        // No level check needed here since the message is already formatted
        // For Zig 0.16, use std.debug.print for simplicity
        _ = self;
        std.debug.print("{s}\n", .{formatted_message});
    }
};
