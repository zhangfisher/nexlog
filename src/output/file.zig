const std = @import("std");
const types = @import("../core/types.zig");
const errors = @import("../core/errors.zig");
const buffer = @import("../utils/buffer.zig");
const handlers = @import("handlers.zig");

fn gzipAvailable() bool {
    // std gzip existed pre-0.15; gone in 0.15.1.
    const has_std_gzip = @hasDecl(std.compress, "gzip");
    return has_std_gzip;
}

var warned_no_gzip = std.atomic.Value(bool).init(false);
fn warnNoGzipOnce() void {
    if (!warned_no_gzip.swap(true, .acq_rel)) {
        std.log.warn("nexlog: gzip compression is deprecated/disabled in this build (Zig 0.15+). Rotated files will be uncompressed.", .{});
    }
}

const FileRotationError = error{
    NoSpaceLeft,
    InvalidUtf8,
    DiskQuota,
    FileTooBig,
    InputOutput,
    DeviceBusy,
    InvalidArgument,
    AccessDenied,
    BrokenPipe,
    SystemResources,
    OperationAborted,
    NotOpenForWriting,
    LockViolation,
    WouldBlock,
    ConnectionResetByPeer,
    ProcessNotFound,
    NoDevice,
    Unexpected,
    OutOfMemory,
    PathAlreadyExists,
    FileNotFound,
    NameTooLong,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    FileBusy,
    FileSystem,
    SharingViolation,
    PipeBusy,
    InvalidWtf8,
    BadPathName,
    NetworkNotFound,
    AntivirusInterference,
    IsDir,
    NotDir,
    FileLocksNotSupported,
    ConnectionTimedOut,
    NotOpenForReading,
    SocketNotConnected,
    Canceled,
    UnfinishedBits,
    ZlibNotImplemented,
    ZstdNotImplemented,
    ReadOnlyFileSystem,
    LinkQuotaExceeded,
    RenameAcrossMountPoints,
} || errors.BufferError || std.Io.File.WriteError;

pub const RotationMode = enum {
    size,
    time,
    both,
};

pub const CompressionType = enum {
    none,
    gzip,
};

pub const FileConfig = struct {
    path: []const u8,
    mode: enum {
        append,
        truncate,
    } = .append,
    max_size: usize = 10 * 1024 * 1024, // 10MB default
    enable_rotation: bool = true,
    max_rotated_files: usize = 5,
    buffer_size: usize = 4096,
    flush_interval_ms: u32 = 1000,
    min_level: types.LogLevel = .debug,

    // New rotation options
    rotation_mode: RotationMode = .size,
    rotation_interval: u64 = 24 * 60 * 60, // Default: 24 hours in seconds
    compression: CompressionType = .none,
    last_rotation: i64 = 0, // Timestamp of last rotation

    // For Zig 0.16 I/O operations - user should provide their own io instance
    io: std.Io,
};

pub const FileHandler = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: FileConfig,
    file: ?std.Io.File,
    mutex: std.atomic.Mutex,
    circular_buffer: *buffer.CircularBuffer,
    last_flush: i64,
    current_size: std.atomic.Value(usize),
    error_handler: ?*const errors.ErrorHandler = null,

    pub fn init(allocator: std.mem.Allocator, config: FileConfig, error_handler: ?*const errors.ErrorHandler) !*Self {
        // Validate config
        if (config.path.len == 0) return error.InvalidPath;
        if (config.buffer_size == 0) return error.InvalidBufferSize;
        if (config.max_size == 0) return error.InvalidMaxSize;

        var cfg = config;
        if (cfg.compression == .gzip and !comptime gzipAvailable()) {
            warnNoGzipOnce();
            cfg.compression = .none;
        }

        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        var circular_buf = try buffer.CircularBuffer.init(allocator, config.buffer_size);
        errdefer circular_buf.deinit();

        self.* = .{
            .allocator = allocator,
            .config = cfg,
            .file = null,
            .mutex = std.atomic.Mutex.unlocked,
            .circular_buffer = circular_buf,
            .last_flush = types.getCurrentTimestamp(),
            .current_size = std.atomic.Value(usize).init(0),
            .error_handler = error_handler,
        };

        // Safe file opening
        self.file = std.Io.Dir.cwd().createFile(config.io, config.path, .{
            .truncate = config.mode == .truncate,
        }) catch |err| {
            self.circular_buffer.deinit();
            self.handleError(err, "Failed to open log file");
            return err;
        };

        if (config.mode == .append) {
            // For append mode, just start with 0 since we're appending
            self.current_size.store(0, .release);
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        _ = self.flush() catch {};
        if (self.file) |file| file.close(self.config.io);
        self.circular_buffer.deinit();
        self.allocator.destroy(self);
    }

    fn handleError(self: *Self, err: anyerror, context: []const u8) void {
        if (self.error_handler) |handler| {
            // Use @call to invoke function pointer in Zig 0.16
            @as(*const fn (anyerror, []const u8) void, @ptrCast(handler))(err, context);
        } else {
            std.debug.print("FileHandler error: {} - {s}\n", .{ err, context });
        }
    }

    pub fn writeLog(self: *Self, level: types.LogLevel, message: []const u8, metadata: ?types.LogMetadata) !void {
        if (@intFromEnum(level) < @intFromEnum(self.config.min_level)) {
            return;
        }

        _ = metadata; // Currently not used but kept for API compatibility

        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        // Format log entry
        var temp_buffer: [4096]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&temp_buffer);
        const allocator = fba.allocator();

        const formatted = try std.fmt.allocPrint(
            allocator,
            "[{d}] [{s}] {s}\n",
            .{ types.getCurrentTimestamp(), level.toString(), message },
        );

        const bytes_written = self.circular_buffer.write(formatted) catch |log_error| {
            self.handleError(log_error, "Failed to write to circular buffer");
            return log_error;
        };

        _ = self.current_size.fetchAdd(bytes_written, .monotonic);

        if (self.shouldFlush()) {
            self.flush() catch |flush_err| {
                self.handleError(flush_err, "Failed to flush log file");
            };
        }
    }

    fn shouldFlush(self: *Self) bool {
        const now = types.getCurrentTimestamp();
        return self.circular_buffer.len() >= self.config.buffer_size / 2 or
            now - self.last_flush >= @as(i64, @intCast(self.config.flush_interval_ms / 1000));
    }

    pub fn flush(self: *Self) !void {
        if (self.circular_buffer.isEmpty()) return;

        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        var temp_buffer: [8192]u8 = undefined;
        const bytes_read = try self.circular_buffer.read(&temp_buffer);

        if (self.file) |file| {
            // Use Io.Writer interface for Zig 0.16 - pass io and buffer
            var writer = file.writer(self.config.io, &temp_buffer);
            try writer.interface.writeAll(temp_buffer[0..bytes_read]);
            try file.sync(self.config.io);
        }

        self.last_flush = types.getCurrentTimestamp();
    }

    pub fn writeFormattedLog(self: *Self, formatted_message: []const u8) !void {
        const bytes_written = self.circular_buffer.write(formatted_message) catch |err| {
            self.handleError(err, "Failed to write formatted log");
            return err;
        };

        _ = self.current_size.fetchAdd(bytes_written, .monotonic);

        if (self.shouldFlush()) {
            self.flush() catch {};
        }
    }

    pub fn rotate(self: *Self) !void {
        lockMutex(&self.mutex);
        defer unlockMutex(&self.mutex);

        if (self.file) |file| {
            file.sync() catch {};
            file.close();
            self.file = null;
        }

        // Shift existing log files
        var i: usize = self.config.max_rotated_files;
        while (i > 0) : (i -= 1) {
            const old_path = if (i == 1)
                try std.fmt.allocPrint(self.allocator, "{s}", .{self.config.path})
            else
                try std.fmt.allocPrint(self.allocator, "{s}.{d}", .{ self.config.path, i - 1 });
            defer self.allocator.free(old_path);

            const new_path = try std.fmt.allocPrint(self.allocator, "{s}.{d}", .{ self.config.path, i });
            defer self.allocator.free(new_path);

            _ = std.Io.Dir.cwd().rename(old_path, new_path) catch {};
        }

        // Create new log file
        self.file = std.Io.Dir.cwd().createFile(self.config.io, self.config.path, .{
            .truncate = true,
        }) catch |err| {
            self.handleError(err, "Failed to create new log file after rotation");
            return err;
        };

        self.current_size.store(0, .release);
    }

    /// Convert to generic LogHandler interface
    pub fn toLogHandler(self: *Self) handlers.LogHandler {
        return handlers.LogHandler.init(
            self,
            .file,
            FileHandler.writeLog,
            FileHandler.writeFormattedLog,
            FileHandler.flush,
            FileHandler.deinit,
        );
    }
};

// Use mutex_helpers for locking
const mutex_helpers = @import("../mutex_helpers.zig");
const lockMutex = mutex_helpers.lockMutex;
const unlockMutex = mutex_helpers.unlockMutex;
