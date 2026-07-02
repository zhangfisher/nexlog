# API 参考

NexLog 的完整 API 文档。

## 核心类型

### Logger

主要的日志记录接口。

```zig
pub const Logger = struct {
    pub fn init(allocator: Allocator, config: LogConfig) !Logger
    pub fn deinit(self: *Logger) void
    
    // 主要日志方法
    pub fn log(self: *Logger, level: LogLevel, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) !void
    
    // 便捷方法（可能返回错误）
    pub fn trace(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) !void
    pub fn debug(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) !void
    pub fn info(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) !void
    pub fn warn(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) !void
    pub fn err(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) !void
    pub fn critical(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) !void
    
    // 不会失败的便捷方法
    pub fn traceNoFail(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) void
    pub fn debugNoFail(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) void
    pub fn infoNoFail(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) void
    pub fn warnNoFail(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) void
    pub fn errNoFail(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) void
    pub fn criticalNoFail(self: *Logger, comptime fmt: []const u8, args: anytype, metadata: ?LogMetadata) void
    
    pub fn flush(self: *Logger) !void
};
```

### LogConfig

日志记录器初始化的配置结构。

```zig
pub const LogConfig = struct {
    min_level: LogLevel = .info,
    enable_colors: bool = true,
    enable_file_logging: bool = false,
    file_path: []const u8 = "app.log",
    max_file_size: usize = 10 * 1024 * 1024,
    max_file_count: usize = 5,
    buffer_size: usize = 8 * 1024,
    flush_interval_ms: u64 = 5000,
    output_format: OutputFormat = .standard,
    custom_template: ?[]const u8 = null,
    timestamp_format: TimestampFormat = .unix,
    level_format: LevelFormat = .upper,
    include_metadata: bool = true,
};
```

### LogLevel

可用的日志级别。

```zig
pub const LogLevel = enum {
    trace,
    debug,
    info,
    warn,
    err,
    critical,
    
    pub fn toString(self: LogLevel) []const u8
    pub fn toStringShort(self: LogLevel) []const u8
    pub fn fromString(str: []const u8) ?LogLevel
};
```

### LogMetadata

附加到日志条目的元数据。

```zig
pub const LogMetadata = struct {
    timestamp: i64,
    thread_id: usize,
    file: []const u8,
    line: u32,
    function: []const u8,
    
    // 创建辅助函数
    pub fn create(src: std.builtin.SourceLocation) LogMetadata
    pub fn createWithTimestamp(timestamp: i64, src: std.builtin.SourceLocation) LogMetadata
    pub fn createWithThreadId(thread_id: usize, src: std.builtin.SourceLocation) LogMetadata
    pub fn minimal() LogMetadata
};
```

## 便捷函数

### 元数据辅助函数

```zig
// 从调用者的源位置创建元数据
pub fn here(src: std.builtin.SourceLocation) LogMetadata

// 使用自定义时间戳创建元数据
pub fn hereWithTimestamp(timestamp: i64, src: std.builtin.SourceLocation) LogMetadata

// 使用自定义线程 ID 创建元数据
pub fn hereWithThreadId(thread_id: usize, src: std.builtin.SourceLocation) LogMetadata
```

用法：
```zig
logger.info("消息", .{}, nexlog.here(@src()));
logger.warn("自定义时间", .{}, nexlog.hereWithTimestamp(1640995200, @src()));
```

## 枚举类型

### OutputFormat

```zig
pub const OutputFormat = enum {
    standard,  // 使用占位符的默认格式
    json,      // JSON 结构化输出
    compact,   // 最小化格式
    custom,    // 使用 custom_template
};
```

### TimestampFormat

```zig
pub const TimestampFormat = enum {
    unix,      // Unix 时间戳: 1640995200
    iso8601,   // ISO8601 格式: 2022-01-01T00:00:00Z
};
```

### LevelFormat

```zig
pub const LevelFormat = enum {
    upper,       // INFO, WARN, ERROR
    lower,       // info, warn, error
    short_upper, // INF, WRN, ERR
    short_lower, // inf, wrn, err
};
```

## 结构化日志

### StructuredField

```zig
pub const StructuredField = struct {
    name: []const u8,
    value: FieldValue,
    attributes: ?std.StringHashMap([]const u8),
};
```

### FieldValue

```zig
pub const FieldValue = union(enum) {
    string: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,
    array: []const FieldValue,
    object: std.StringHashMap(FieldValue),
    null_value,
    
    pub fn toString(self: FieldValue, allocator: Allocator) ![]const u8
};
```

### Formatter

```zig
pub const Formatter = struct {
    pub fn init(allocator: Allocator, config: FormatConfig) !Formatter
    pub fn deinit(self: *Formatter) void
    
    pub fn format(
        self: *Formatter,
        level: LogLevel,
        message: []const u8,
        metadata: LogMetadata,
    ) ![]const u8
    
    pub fn formatStructured(
        self: *Formatter,
        level: LogLevel,
        message: []const u8,
        fields: []const StructuredField,
        metadata: LogMetadata,
    ) ![]const u8
};
```

## 初始化函数

### 基本初始化

```zig
// 使用默认配置初始化
pub fn init(allocator: Allocator) !void

// 使用自定义配置初始化
pub fn initWithConfig(allocator: Allocator, config: LogConfig) !void

// 清理资源
pub fn deinit() void

// 检查是否已初始化
pub fn isInitialized() bool

// 获取默认日志记录器实例
pub fn getDefaultLogger() *Logger
```

### 构建器模式

```zig
pub const LogBuilder = struct {
    pub fn new(allocator: Allocator) LogBuilder
    pub fn withLevel(self: *LogBuilder, level: LogLevel) *LogBuilder
    pub fn withColors(self: *LogBuilder, enable: bool) *LogBuilder
    pub fn withFile(self: *LogBuilder, path: []const u8) *LogBuilder
    pub fn withBuffer(self: *LogBuilder, size: usize) *LogBuilder
    pub fn build(self: *LogBuilder) !Logger
};
```

用法：
```zig
var logger = try LogBuilder.new(allocator)
    .withLevel(.debug)
    .withColors(true)
    .withFile("app.log")
    .build();
```

## 错误类型

```zig
pub const LogError = error{
    OutOfMemory,
    FileNotFound,
    AccessDenied,
    InvalidConfig,
    InvalidTemplate,
    BufferFull,
    InitializationFailed,
};
```

## 工具类型

### CircularBuffer

```zig
pub const CircularBuffer = struct {
    pub fn init(allocator: Allocator, capacity: usize) !CircularBuffer
    pub fn deinit(self: *CircularBuffer) void
    pub fn write(self: *CircularBuffer, data: []const u8) !void
    pub fn read(self: *CircularBuffer, buffer: []u8) usize
    pub fn available(self: *CircularBuffer) usize
    pub fn capacity(self: *CircularBuffer) usize
};
```

### Pool

```zig
pub const Pool = struct {
    pub fn init(allocator: Allocator, capacity: usize) !Pool
    pub fn deinit(self: *Pool) void
    pub fn acquire(self: *Pool) ![]u8
    pub fn release(self: *Pool, buffer: []u8) void
};
```

## 线程安全

除非另有说明，所有公共 API 函数都是线程安全的。内部同步使用：

- 互斥锁用于日志记录器状态
- 原子操作用于计数器
- 尽可能使用无锁算法

## 内存管理

- 所有分配都使用提供的分配器
- 尽可能重用缓冲区以最小化分配
- 调用所有创建对象的 `deinit()` 以释放资源
- 使用 `defer` 语句确保清理

## 示例用法

```zig
const std = @import("std");
const nexlog = @import("nexlog");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 创建日志记录器
    const config = nexlog.LogConfig{
        .min_level = .debug,
        .enable_colors = true,
    };
    const logger = try nexlog.Logger.init(allocator, config);
    defer logger.deinit();

    // 记录消息
    try logger.info("应用程序启动", .{}, nexlog.here(@src()));
    try logger.debug("调试信息: {}", .{42}, nexlog.here(@src()));
    
    // 不会失败的便捷方法
    logger.warnNoFail("警告消息", .{}, nexlog.here(@src()));
    
    // 手动刷新
    try logger.flush();
}
```
