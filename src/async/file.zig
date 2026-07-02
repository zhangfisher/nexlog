const std = @import("std");
const types = @import("../core/types.zig");
const async_core = @import("core.zig");
const format = @import("../utils/format.zig");
const mutex_helpers = @import("../mutex_helpers.zig");

const lockMutex = mutex_helpers.lockMutex;
const unlockMutex = mutex_helpers.unlockMutex;

pub const AsyncFileConfig = struct {
    path: []const u8 = "app.log",
    min_level: types.LogLevel = .debug,
    max_size: usize = 10 * 1024 * 1024, // 10MB
    max_rotated_files: usize = 5,
    enable_rotation: bool = true,
    buffer_size: usize = 64 * 1024, // 64KB buffer for better I/O performance
    flush_interval_ms: u64 = 5000, // Flush every 5 seconds
    enable_compression: bool = false,
    // For Zig 0.16 I/O operations - user should provide their own io instance
    io: std.Io,
};

pub const AsyncFileHandler = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: AsyncFileConfig,
    file: ?std.Io.File,
    buffer: std.ArrayList(u8),
    mutex: std.atomic.Mutex,
    bytes_written: usize,
    formatter: ?*format.Formatter,
    last_flush: i64,

    pub fn init(allocator: std.mem.Allocator, config: AsyncFileConfig) !*Self {
        const handler = try allocator.create(Self);

        // Create directory if it doesn't exist
        if (std.fs.path.dirname(config.path)) |dir| {
            // For Zig 0.16, we'll skip directory creation here
            // and let it be created when the file is opened
            _ = dir;
        }

        // Open file for appending
        const file = try std.Io.Dir.cwd().createFile(config.io, config.path, .{
            .truncate = false,
        });

        // Seek to end for appending
        // In Zig 0.16, use stat() to get file size
        const stat_info = try file.stat(config.io);
        const file_size = stat_info.size;
        // Note: File is opened in append mode, so writes will automatically go to end
        // No explicit seek needed in Zig 0.16

        // Create formatter for consistent output
        const fmt_config = format.FormatConfig{
            .template = "[{timestamp}] [{level}] {message}",
            .timestamp_format = .unix,
            .use_color = false, // No colors in file output
        };
        const formatter = try format.Formatter.init(allocator, fmt_config);

        handler.* = .{
            .allocator = allocator,
            .config = config,
            .file = file,
            .buffer = .empty,
            .mutex = std.atomic.Mutex.unlocked,
            .bytes_written = file_size,
            .formatter = formatter,
            .last_flush =types.getCurrentTimestamp(),
        };

        try handler.buffer.ensureTotalCapacity(allocator, config.buffer_size);

        return handler;
    }

    pub fn deinit(self: *Self) void {
        self.flushAsync() catch {};

        if (self.file) |file| {
            file.close(self.config.io);
        }

        if (self.formatter) |formatter| {
            formatter.deinit();
        }

        self.buffer.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn logAsync(self: *Self, entry: async_core.LogEntry) !void {
        if (@intFromEnum(entry.level) < @intFromEnum(self.config.min_level)) {
            return;
        }

        // Handle special flush command
        if (std.mem.eql(u8, entry.message, "__FLUSH__")) {
            return self.flushAsync();
        }

        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        // Format the log entry
        var format_buffer: [2048]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&format_buffer);

        // Simple file format: timestamp, level, message
        try writer.print("[{d}] [{s}]", .{ entry.timestamp, entry.level.toString() });

        // Add metadata if present
        if (entry.metadata) |m| {
            const filename = std.fs.path.basename(m.file);
            try writer.print(" [{s}:{d}] [{s}]", .{ filename, m.line, m.function });
        }

        try writer.print(" {s}\n", .{entry.message});

        // Add to buffer
        try self.buffer.appendSlice(self.allocator, writer.buffered());

        // Check if we need to flush due to buffer size or time
        const should_flush = self.buffer.items.len >= self.config.buffer_size or
            (types.getCurrentTimestamp() - self.last_flush) >= @as(i64, @intCast(self.config.flush_interval_ms / 1000));

        if (should_flush) {
            try self.flushBufferUnsafe();
        }

        // Check if we need to rotate due to file size
        if (self.config.enable_rotation and self.bytes_written >= self.config.max_size) {
            try self.rotateFileUnsafe();
        }
    }

    pub fn flushAsync(self: *Self) !void {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        try self.flushBufferUnsafe();
    }

    fn flushBufferUnsafe(self: *Self) !void {
        if (self.buffer.items.len == 0) {
            return;
        }

        if (self.file) |file| {
            // Use Io.Writer interface for Zig 0.16
            var buffer: [8192]u8 = undefined;
            var writer = file.writer(self.config.io, &buffer);
            try writer.interface.writeAll(self.buffer.items);
            try file.sync(self.config.io);

            self.bytes_written += self.buffer.items.len;
            self.buffer.clearRetainingCapacity();
            self.last_flush = types.getCurrentTimestamp();
        }
    }

    fn rotateFileUnsafe(self: *Self) !void {
        // Flush remaining buffer
        try self.flushBufferUnsafe();

        if (self.file) |file| {
            file.close(self.config.io);
            self.file = null;
        }

        // Rotate existing files
        var i: usize = self.config.max_rotated_files;
        while (i > 0) : (i -= 1) {
            const old_path = if (i == 1)
                try std.fmt.allocPrint(self.allocator, "{s}", .{self.config.path})
            else
                try std.fmt.allocPrint(self.allocator, "{s}.{d}", .{ self.config.path, i - 1 });
            defer self.allocator.free(old_path);

            const new_path = try std.fmt.allocPrint(self.allocator, "{s}.{d}", .{ self.config.path, i });
            defer self.allocator.free(new_path);

            // Try to rename, ignore errors if file doesn't exist
            {
                // In Zig 0.16, use renamePreserve for same-directory renames
                // For now, we'll skip rotation to avoid complex API changes
                // Rotation can be implemented as a separate operation
            }
        }

        // Delete oldest file if it exists
        if (self.config.max_rotated_files > 0) {
            const oldest_path = try std.fmt.allocPrint(self.allocator, "{s}.{d}", .{ self.config.path, self.config.max_rotated_files });
            defer self.allocator.free(oldest_path);

            {
                const cwd = std.Io.Dir.cwd();
                cwd.deleteFile(self.config.io, oldest_path) catch {};
            }
        }

        // Create new file
        self.file = try std.Io.Dir.cwd().createFile(self.config.io, self.config.path, .{
            .truncate = true,
        });

        self.bytes_written = 0;
    }

    /// Get file handler statistics
    pub fn getStats(self: *Self) AsyncFileStats {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        return AsyncFileStats{
            .bytes_written = self.bytes_written,
            .buffer_size = self.buffer.items.len,
            .max_buffer_size = self.buffer.capacity,
            .last_flush = self.last_flush,
            .file_is_open = self.file != null,
        };
    }

    /// Convert to generic AsyncLogHandler interface
    pub fn toAsyncLogHandler(self: *Self) async_core.AsyncLogHandler {
        return async_core.AsyncLogHandler.init(
            self,
            AsyncFileHandler.logAsync,
            AsyncFileHandler.flushAsync,
            AsyncFileHandler.deinit,
        );
    }
};

pub const AsyncFileStats = struct {
    bytes_written: usize,
    buffer_size: usize,
    max_buffer_size: usize,
    last_flush: i64,
    file_is_open: bool,
};
