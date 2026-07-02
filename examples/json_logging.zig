const std = @import("std");
const nexlog = @import("nexlog");
const JsonHandler = nexlog.output.json_handler.JsonHandler;
const types = nexlog.core.types;

pub fn main() !void {
    // Zig 0.16: use simple allocator
    const allocator = std.heap.page_allocator;

    // Create a directory for testing logs if it doesn't exist
    // const log_dir = "test_logs"; // Not used, commented out
    const log_file_path = "test_logs/app.json";

    // Create a JSON handler with simple path
    var json_handler = try JsonHandler.init(allocator, .{
        .min_level = .debug,
        .pretty_print = true,
        .output_file = log_file_path,
    });

    // Create a logger
    const logger = try nexlog.Logger.init(allocator, .{});
    defer logger.deinit();

    // Add the JSON handler to the logger
    try logger.addHandler(json_handler.toLogHandler());

    // Create some basic metadata
    const metadata = nexlog.LogMetadata{
        .timestamp = types.getCurrentTimestamp(),
        .thread_id = 0, // Replace with actual thread ID in a real application
        .file = @src().file,
        .line = @src().line,
        .function = @src().fn_name,
    };

    // Log some messages with different levels and optional fields
    // Log some messages with different levels and optional fields
    try logger.log(.info, "Application starting", .{}, metadata);
    try logger.log(.debug, "This is a debug message", .{}, metadata);
    try logger.log(.warn, "This is a warning message (code: {d})", .{123}, metadata);
    try logger.log(.err, "An error occurred (code: {s})", .{"E_UNKNOWN"}, metadata);

    // Ensure all logs are written before exiting
    try logger.flush();
}
