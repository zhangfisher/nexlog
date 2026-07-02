const std = @import("std");
const nexlog = @import("nexlog");
const types = nexlog.core.types;

pub fn main() !void {
    // Zig 0.16: use simple allocator
    const allocator = std.heap.page_allocator;

    // Create a simple IO instance for file operations
    // In Zig 0.16, create a Threaded instance and get its io
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();

    std.debug.print("=== Nexlog Async Logging Demo ===\n\n", .{});

    // Create async logger with custom config
    const async_config = nexlog.AsyncLogConfig{
        .min_level = .debug,
        .queue_size = 10000,
        .enable_backpressure = true,
    };

    var async_logger = try nexlog.AsyncLogger.init(allocator, async_config);
    defer async_logger.deinit();

    // Create and add async console handler
    const console_config = nexlog.async_logging.AsyncConsoleConfig{
        .enable_colors = true,
        .fast_mode = false,
        .show_source_location = true,
        .use_stderr = false,
    };

    var console_handler = try nexlog.AsyncConsoleHandler.init(allocator, console_config);
    defer console_handler.deinit();

    var console_async_handler = console_handler.toAsyncLogHandler();
    try async_logger.addHandler(&console_async_handler);

    // Create and add async file handler
    // Note: In Zig 0.16, directory creation requires specific permissions
    // We'll let the file handler create the directory as needed

    const file_config = nexlog.async_logging.AsyncFileConfig{
        .path = "logs/async_demo.log",
        .max_size = 1024 * 1024, // 1MB
        .max_rotated_files = 3,
        .enable_rotation = true,
        .buffer_size = 8192, // 8KB buffer
        .flush_interval_ms = 2000, // Flush every 2 seconds
        .io = io,
    };

    var file_handler = try nexlog.AsyncFileHandler.init(allocator, file_config);
    defer file_handler.deinit();

    var file_async_handler = file_handler.toAsyncLogHandler();
    try async_logger.addHandler(&file_async_handler);

    // Start the async logger
    try async_logger.start();
    defer async_logger.stop();

    std.debug.print("1. Basic async logging...\n", .{});

    // Demo 1: Basic async logging
    const metadata = nexlog.LogMetadata{
        .timestamp = types.getCurrentTimestamp(),
        .thread_id = std.Thread.getCurrentId(),
        .file = "async_demo.zig",
        .line = 65,
        .function = "main",
    };

    try async_logger.infoAsync("Async logger started successfully", .{}, metadata);
    try async_logger.debugAsync("This is a debug message from async logger", .{}, metadata);
    try async_logger.warnAsync("Warning: This is an async warning message", .{}, metadata);

    std.debug.print("2. High-throughput logging simulation...\n", .{});

    // Demo 2: High-throughput logging simulation
    const start_time = std.Io.Clock.now(.real, io).nanoseconds;
    const log_count = 1000;

    for (0..log_count) |i| {
        try async_logger.infoAsync("High-throughput log entry #{d}", .{i}, metadata);

        if (i % 100 == 0) {
            const stats = async_logger.getStats();
            std.debug.print("  Progress: {d}/{d}, Queue: {d}, Processed: {d}\n", .{ i, log_count, stats.queue_size, stats.processed_logs });
        }
    }

    const end_time = std.Io.Clock.now(.real, io).nanoseconds;
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

    std.debug.print("  Logged {d} entries in {d:.2}ms\n", .{ log_count, duration_ms });
    std.debug.print("  Throughput: {d:.0} logs/second\n", .{@as(f64, @floatFromInt(log_count)) / (duration_ms / 1000.0)});

    std.debug.print("3. Multi-threaded logging simulation...\n", .{});

    // Demo 3: Multi-threaded logging
    const thread_count = 4;
    var threads: [thread_count]std.Thread = undefined;

    for (0..thread_count) |i| {
        threads[i] = try std.Thread.spawn(.{}, workerThread, .{ async_logger, i });
    }

    for (threads) |thread| {
        thread.join();
    }

    std.debug.print("4. Async flush and statistics...\n", .{});

    // Demo 4: Flush and get final statistics
    try async_logger.flushAsync();

    // Wait a bit for processing to complete
    try std.Io.sleep(io, .{ .nanoseconds = 100_000_000 }, .real); // 100ms

    const final_stats = async_logger.getStats();
    const file_stats = file_handler.getStats();

    std.debug.print("\n=== Final Statistics ===\n", .{});
    std.debug.print("Logger Stats:\n", .{});
    std.debug.print("  Queue Size: {d}/{d}\n", .{ final_stats.queue_size, final_stats.max_queue_size });
    std.debug.print("  Processed Logs: {d}\n", .{final_stats.processed_logs});
    std.debug.print("  Dropped Logs: {d}\n", .{final_stats.dropped_logs});
    std.debug.print("  Processing Errors: {d}\n", .{final_stats.processing_errors});
    std.debug.print("  Handler Errors: {d}\n", .{final_stats.handler_errors});

    std.debug.print("\nFile Handler Stats:\n", .{});
    std.debug.print("  Bytes Written: {d}\n", .{file_stats.bytes_written});
    std.debug.print("  Buffer Size: {d}/{d}\n", .{ file_stats.buffer_size, file_stats.max_buffer_size });
    std.debug.print("  File Open: {}\n", .{file_stats.file_is_open});

    std.debug.print("5. Graceful shutdown...\n", .{});

    // Demo 5: Graceful shutdown with drain
    try async_logger.drain(5000); // Wait up to 5 seconds for queue to drain

    std.debug.print("\n=== Async Logging Demo Complete! ===\n", .{});
    std.debug.print("Check 'logs/async_demo.log' for file output.\n", .{});
}

fn workerThread(async_logger: *nexlog.AsyncLogger, thread_id: usize) void {
    const metadata = nexlog.LogMetadata{
        .timestamp = types.getCurrentTimestamp(),
        .thread_id = std.Thread.getCurrentId(),
        .file = "async_demo.zig",
        .line = 140,
        .function = "workerThread",
    };

    for (0..50) |i| {
        async_logger.infoAsync("Thread {d} - Message {d}", .{ thread_id, i }, metadata) catch |err| {
            std.debug.print("Worker thread {d} error: {}\n", .{ thread_id, err });
            return;
        };

        // Small delay to simulate work
        // Create local Io instance for Zig 0.16
        var io_threaded: std.Io.Threaded = .init_single_threaded;
        const worker_io = io_threaded.io();
        std.Io.sleep(worker_io, .{ .nanoseconds = 1_000_000 }, .real) catch {}; // 1ms
    }
}
