# 配置参考

NexLog 的完整配置参考。

## LogConfig

用于初始化日志记录器的主要配置结构。

```zig
const config = nexlog.LogConfig{
    // 基本设置
    .min_level = .info,
    .enable_colors = true,
    .output_format = .standard,
    
    // 文件日志
    .enable_file_logging = false,
    .file_path = "app.log",
    .max_file_size = 10 * 1024 * 1024,
    .max_file_count = 5,
    
    // 性能
    .buffer_size = 8 * 1024,
    .flush_interval_ms = 5000,
    
    // 格式化
    .custom_template = null,
    .timestamp_format = .unix,
    .level_format = .upper,
    .include_metadata = true,
};
```

## 基本设置

### min_level
**类型：** `LogLevel`  
**默认值：** `.info`  
**描述：** 输出的最低日志级别。低于此级别的消息将被忽略。

```zig
.min_level = .debug, // 记录 debug 级别及以上的日志
.min_level = .warn,  // 仅记录警告和错误
```

### enable_colors
**类型：** `bool`  
**默认值：** `true`  
**描述：** 在控制台日志中启用彩色输出。

```zig
.enable_colors = true,  // 彩色输出
.enable_colors = false, // 纯文本
```

### output_format
**类型：** `OutputFormat`  
**默认值：** `.standard`  
**选项：** `.standard`, `.json`, `.compact`, `.custom`

```zig
.output_format = .json,     // JSON 结构化日志
.output_format = .compact,  // 最小化格式
.output_format = .custom,   // 使用 custom_template
```

## 文件日志

### enable_file_logging
**类型：** `bool`  
**默认值：** `false`  
**描述：** 除了控制台外，还启用文件日志记录。

### file_path
**类型：** `[]const u8`  
**默认值：** `"app.log"`  
**描述：** 日志文件写入的路径。

```zig
.file_path = "logs/application.log",
.file_path = "/var/log/myapp.log",
```

### max_file_size
**类型：** `usize`  
**默认值：** `10 * 1024 * 1024` (10MB)  
**描述：** 文件轮转前的最大大小。

```zig
.max_file_size = 50 * 1024 * 1024, // 50MB
.max_file_size = 1024 * 1024,      // 1MB
```

### max_file_count
**类型：** `usize`  
**默认值：** `5`  
**描述：** 保留的轮转文件数量。

```zig
.max_file_count = 10, // 保留 10 个旧文件
.max_file_count = 1,  // 仅保留当前文件
```

## 性能设置

### buffer_size
**类型：** `usize`  
**默认值：** `8 * 1024` (8KB)  
**描述：** 用于批量写入日志的内部缓冲区大小。

```zig
.buffer_size = 64 * 1024, // 64KB 缓冲区用于高吞吐量
.buffer_size = 1024,      // 1KB 用于低内存使用
```

### flush_interval_ms
**类型：** `u64`  
**默认值：** `5000` (5 秒)  
**描述：** 将缓冲日志刷新到磁盘的频率。

```zig
.flush_interval_ms = 1000, // 每秒刷新
.flush_interval_ms = 0,    // 立即刷新（无缓冲）
```

## 格式化选项

### custom_template
**类型：** `?[]const u8`  
**默认值：** `null`  
**描述：** 自定义格式模板。需要 `output_format = .custom`。

```zig
.custom_template = "{timestamp} [{level}] {message}",
.custom_template = "[{level:>5}] {file}:{line} - {message}",
```

### timestamp_format
**类型：** `TimestampFormat`  
**默认值：** `.unix`  
**选项：** `.unix`, `.iso8601`

```zig
.timestamp_format = .unix,    // 1640995200
.timestamp_format = .iso8601, // 2022-01-01T00:00:00Z
```

### level_format
**类型：** `LevelFormat`  
**默认值：** `.upper`  
**选项：** `.upper`, `.lower`, `.short_upper`, `.short_lower`

```zig
.level_format = .upper,       // INFO, WARN, ERROR
.level_format = .lower,       // info, warn, error
.level_format = .short_upper, // INF, WRN, ERR
.level_format = .short_lower, // inf, wrn, err
```

### include_metadata
**类型：** `bool`  
**默认值：** `true`  
**描述：** 包含源文件、行号和函数信息。

```zig
.include_metadata = true,  // 显示文件:行信息
.include_metadata = false, // 仅时间戳、级别、消息
```

## 日志级别

按严重程度排序的可用日志级别：

```zig
pub const LogLevel = enum {
    trace,    // 最详细
    debug,    // 调试信息
    info,     // 一般信息
    warn,     // 警告
    err,      // 错误
    critical, // 严重错误
};
```

## 环境变量

某些设置可以通过环境变量覆盖：

- `NEXLOG_LEVEL`: 覆盖 min_level (`debug`, `info`, `warn`, `error`)
- `NEXLOG_COLOR`: 覆盖 enable_colors (`true`, `false`)
- `NEXLOG_FILE`: 覆盖 file_path
- `NEXLOG_FORMAT`: 覆盖 output_format (`standard`, `json`, `compact`)

## 验证

NexLog 在初始化时验证配置：

```zig
// 无效配置将返回错误
const bad_config = nexlog.LogConfig{
    .max_file_size = 0,           // 错误：大小必须 > 0
    .custom_template = "{bad}",   // 错误：未知的占位符
    .buffer_size = 0,             // 错误：缓冲区必须 > 0
};

const logger = nexlog.Logger.init(allocator, bad_config) catch |err| {
    // 处理配置错误
    std.debug.print("配置错误: {}\n", .{err});
    return;
};
```

## 性能建议

### 高吞吐量应用程序
```zig
const config = nexlog.LogConfig{
    .min_level = .warn,           // 减少日志量
    .buffer_size = 64 * 1024,     // 大缓冲区
    .flush_interval_ms = 1000,    // 较少刷新
    .enable_colors = false,       // 跳过颜色处理
    .include_metadata = false,    // 最小化格式化
};
```

### 开发环境
```zig
const config = nexlog.LogConfig{
    .min_level = .debug,          // 详细日志
    .enable_colors = true,        // 可读输出
    .include_metadata = true,     // 完整上下文
    .flush_interval_ms = 0,       // 立即输出
};
```

### 生产环境
```zig
const config = nexlog.LogConfig{
    .min_level = .info,
    .output_format = .json,       // 结构化便于聚合
    .enable_file_logging = true,  // 持久化日志
    .max_file_size = 100 * 1024 * 1024, // 100MB 文件
    .enable_colors = false,       // 文件中不使用颜色
};
```
