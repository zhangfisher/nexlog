// errors.zig
const std = @import("std");
const types = @import("types.zig");

pub const Error = error{
    IOError,
    ConfigError,
    BufferError,
    Unexpected,
    AlreadyInitialized,
};

pub const ErrorContext = struct {
    file: []const u8,
    line: u32,
    error_type: Error,
    message: []const u8,
    timestamp: i64,

    pub fn init(
        error_type: Error,
        message: []const u8,
        file: []const u8,
        line: u32,
    ) ErrorContext {
        return .{
            .error_type = error_type,
            .message = message,
            .file = file,
            .line = line,
            .timestamp = types.getCurrentTimestamp(),
        };
    }

    pub fn format(self: ErrorContext, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print(
            "Error[{d}] {s}:{d}: {s} - {s}\n",
            .{
                self.timestamp,
                self.file,
                self.line,
                @errorName(self.error_type),
                self.message,
            },
        );
    }
};

pub const ErrorHandler = *const fn (err: anyerror, context: []const u8) void;

pub const ErrorConfig = struct {
    handler: ErrorHandler = null,
    max_retries: u32 = 3,
    retry_delay_ms: u32 = 1000,
};

/// Default error handler that just prints to stderr
pub fn defaultErrorHandler(err: anyerror, context: []const u8) void {
    std.debug.print("Error: {} - {s}\n", .{ err, context });
}
