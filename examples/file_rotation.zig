const std = @import("std");
const nexlog = @import("nexlog");
const types = nexlog.core.types;

pub fn main(init: std.process.Init) !void {
    // Zig 0.16: use Juicy Main pattern
    const allocator = init.gpa;
    const io = init.io;

    // Create logs directory if it doesn't exist
    // Note: In Zig 0.16, file operations need proper I/O handling
    // For now, we'll use a simpler approach
    const log_path = "logs";
    _ = log_path; // Suppress unused warning

    // Initialize logger with small file size to demonstrate rotation

    // Initialize logger with small file size to demonstrate rotation
    var builder = nexlog.LogBuilder.init();
    try builder
        .setMinLevel(.debug)
        .enableColors(true)
        .setBufferSize(4096)
        // Set small max file size to see rotation in action
        .enableFileLogging(true, "logs/test.log")
        .setMaxFileSize(1024) // 1KB - small size to trigger rotations quickly
        .setMaxRotatedFiles(3) // Keep 3 backup files
        // TODO: fix stackoverflow when enableRotation is true in rotate function
        .enableRotation(true)
        .build(allocator);

    defer nexlog.deinit();

    const logger = nexlog.getDefaultLogger() orelse return error.LoggerNotInitialized;

    // Create base metadata
    const base_metadata = nexlog.LogMetadata{
        .timestamp = types.getCurrentTimestamp(),
        .thread_id = 0,
        .file = @src().file,
        .line = @src().line,
        .function = @src().fn_name,
    };

    // Function to generate a long message
    const generateMessage = struct {
        fn gen(alloc: std.mem.Allocator, id: usize) ![]const u8 {
            return try std.fmt.allocPrint(alloc, "This is log message #{d} with some padding to make it longer... {d} {d}", .{ id, id, id } // Ensure enough arguments to match format specifiers
            );
        }
    }.gen;

    // Log startup
    try logger.log(.info, "Starting file rotation demonstration", .{}, base_metadata);
    try logger.flush();

    // Generate enough logs to trigger multiple rotations
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const msg = try generateMessage(allocator, i);
        defer allocator.free(msg);

        // Log with different levels to make it interesting
        const level: nexlog.LogLevel = switch (i % 4) {
            0 => .info,
            1 => .debug,
            2 => .warn,
            else => .err,
        };

        try logger.log(level, "{s}", .{msg}, base_metadata);
        try logger.flush(); // Ensure immediate write

        // Add small delay to make it more realistic - use std.Io.sleep for Zig 0.16 with Duration and Clock
        try std.Io.sleep(io, .{ .nanoseconds = 50 * std.time.ns_per_ms }, .real);

        // Every 25 messages, log a notification
        if (i % 25 == 0) {
            try logger.log(.info, "Processed {d} messages, check logs directory for rotated files", .{i}, base_metadata);
        }
    }

    // Log completion
    try logger.log(.info, "Demonstration complete - check logs/test.log and logs/test.log.1-3", .{}, base_metadata);

    // List all log files - use std.Io.Dir.cwd for Zig 0.16
    const cwd = std.Io.Dir.cwd();
    var dir = try cwd.openDir(io, "logs", .{ .iterate = true });
    defer dir.close(io);

    var dir_iter = dir.iterate();
    while (try dir_iter.next(io)) |entry| {
        if (std.mem.startsWith(u8, entry.name, "test.log")) {
            const file_info = try dir.statFile(io, entry.name, .{});
            try logger.log(.info, "Found log file: {s} (size: {d} bytes)", .{ entry.name, file_info.size }, base_metadata);
        }
    }
}
