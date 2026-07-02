# nexlog <br/>

![Zig 0.16.0 Compatible](https://img.shields.io/badge/Zig-0.16.0-compatible-brightgreen)
<!-- Space for transparent logo -->
<div align="center">
  <!-- Logo will go here -->
<img src="docs/logo.png" alt="nexlog" width="200" height="200">
</div>

A powerful, fast, and beautifully simple logging library for Zig applications. Built from the ground up to handle everything from quick debugging to production-scale logging with grace.

[![Latest Release](https://img.shields.io/github/v/release/awacsm81/nexlog?include_prereleases&sort=semver)](https://github.com/awacsm81/nexlog/releases)
[![Performance](https://img.shields.io/badge/Performance-40K%20logs%2Fs-brightgreen)](https://github.com/chrischtel/nexlog#benchmarks)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

---

**Current Version: v0.7.1** | **Zig Compatibility: 0.14.0, 0.15.0, 0.16.0**

> ✅ **Fully upgraded to Zig 0.16.0!** All APIs have been updated to support the latest Zig standard library changes including `std.Io`, `std.process.Init`, and more.

## Why nexlog?

After working with logging libraries across different languages, I found myself constantly missing features or fighting with overly complex APIs. nexlog was born from the simple idea that logging should be powerful when you need it, but never get in your way when you don't.

Whether you're debugging a quick script or building a distributed system that needs to track requests across services, nexlog scales with your needs.

## Features

**Core Logging**

- Multiple log levels with beautiful colored output
- Automatic source location tracking (file, line, function)
- Rich metadata support with timestamps and thread IDs
- Zero-overhead when logging is disabled

**Advanced Features**

- Context tracking for following requests across your application
- Structured logging with JSON, logfmt, and custom formats
- Automatic file rotation with configurable size limits
- Custom handlers for sending logs anywhere
- High-performance async mode for demanding applications
- Type-safe API with full Zig compile-time guarantees

## Installation

### 方法 1: 通过 Git URL (推荐)

在你的 `build.zig.zon` 文件中添加 nexlog 依赖：

```zig
.{
    .name = .my_project,
    .version = "0.1.0",
    .dependencies = .{
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.7.1.tar.gz",
            .hash = "", // 留空，首次运行时会自动填充
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

然后运行构建，Zig 会自动下载并缓存依赖：

```bash
zig build
# 首次运行会自动填充 hash 并下载依赖
```

### 方法 2: 使用本地路径 (开发中)

```zig
.{
    .name = .my_project,
    .version = "0.1.0",
    .dependencies = .{
        .nexlog = .{
            .path = "../nexlog", // 相对路径或绝对路径
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

### 方法 3: 使用 `--fork` 测试本地修改

```bash
# 测试本地修改的 nexlog 版本
zig build --fork=../nexlog
```

### 在 `build.zig` 中配置模块

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 导入 nexlog 依赖
    const nexlog_dep = b.dependency("nexlog", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my_app",
        .root_source_file = b.path("src/main.zig"),
    });

    // 添加 nexlog 模块
    exe.root_module.addImport("nexlog", nexlog_dep.module("nexlog"));
    b.installArtifact(exe);
}
```

## Quick Start

Get up and running in minutes with Zig 0.16's "Juicy Main" pattern:

```zig
const std = @import("std");
const nexlog = @import("nexlog");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const allocator = gpa.allocator();

    // Initialize logger with minimal configuration
    const logger = try nexlog.Logger.init(allocator, .{});
    defer logger.deinit();

    // Start logging with automatic source location tracking
    logger.info("Application starting", .{}, nexlog.here(@src()));
    logger.debug("Initializing subsystems", .{}, nexlog.here(@src()));
    logger.warn("Resource usage high", .{}, nexlog.here(@src()));
    logger.info("Application shutdown complete", .{}, nexlog.here(@src()));
}
```

> **💡 Zig 0.16 更新**: 现在使用 `std.process.Init` 作为 main 函数参数，提供更好的资源管理和 I/O 支持。通过 `init.gpa` 和 `init.io` 访问分配器和 I/O 接口。

## Real-World Examples

### Context Tracking for Request Flows

Track user requests as they flow through your application. Perfect for debugging distributed systems or complex request handling:

```zig
// Set request context once at the entry point
nexlog.setRequestContext("req-12345", "user_login");
defer nexlog.clearContext();

logger.info("Processing user login for {s}", .{user_id}, nexlog.hereWithContext(@src()));

// All subsequent logs automatically include request context
try authenticateUser(logger, user_id);
try loadUserProfile(logger, user_id);

logger.info("User login completed successfully", .{}, nexlog.hereWithContext(@src()));
```

### Structured Logging for Analytics

When you need machine-readable logs for monitoring and analytics:

```zig
// Configure formatter for JSON output
const config = format.FormatConfig{
    .structured_format = .json,
    .include_timestamp_in_structured = true,
    .include_level_in_structured = true,
};

var formatter = try format.Formatter.init(allocator, config);
defer formatter.deinit();

// Create structured fields for rich context
const fields = [_]format.StructuredField{
    .{ .name = "user_id", .value = "12345", .attributes = null },
    .{ .name = "request_duration_ms", .value = "150", .attributes = null },
    .{ .name = "endpoint", .value = "/api/login", .attributes = null },
};

logger.info("API request completed", .{}, &fields);
```

### Smart File Rotation

Never worry about log files filling up your disk:

```zig
var builder = nexlog.LogBuilder.init();
try builder
    .setMinLevel(.debug)
    .enableFileLogging(true, "logs/app.log")
    .setMaxFileSize(10 * 1024 * 1024)  // 10MB per file
    .setMaxRotatedFiles(5)             // Keep 5 backup files
    .enableRotation(true)
    .build(allocator);

// Automatically creates: app.log, app.log.1, app.log.2, etc.
```

### Custom Handlers for Specialized Needs

Send logs to external services, databases, or custom destinations:

```zig
pub const CustomHandler = struct {
    allocator: std.mem.Allocator,
    messages: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) !*@This() {
        const handler = try allocator.create(@This());
        handler.* = .{
            .allocator = allocator,
            .messages = std.ArrayList([]const u8).init(allocator),
        };
        return handler;
    }

    pub fn log(self: *@This(), level: LogLevel, message: []const u8, metadata: LogMetadata) !void {
        // Custom logic: store, forward, filter, transform, etc.
        const stored_message = try self.allocator.dupe(u8, message);
        try self.messages.append(stored_message);
    }
};
```

## Performance That Matters

Recent benchmarks show nexlog handles high-throughput scenarios gracefully:

| Scenario                    | Logs/Second | Notes                       |
| --------------------------- | ----------- | --------------------------- |
| Simple console logging      | 41,297      | Basic text output           |
| JSON structured logging     | 26,790      | Full structured format      |
| Logfmt output               | 39,284      | Key-value format            |
| Large payloads (100 fields) | 8,594       | Complex structured data     |
| Production integration      | 5,878       | Full pipeline with handlers |

Run the benchmarks yourself:

```bash
zig build bench
```

## Configuration

Configure nexlog to fit your specific needs:

```zig
var builder = nexlog.LogBuilder.init();
try builder
    .setMinLevel(.debug)
    .enableColors(true)
    .setBufferSize(8192)
    .enableFileLogging(true, "logs/app.log")
    .setMaxFileSize(5 * 1024 * 1024)
    .setMaxRotatedFiles(3)
    .enableRotation(true)
    .enableAsyncMode(true)
    .build(allocator);
```

## Learning More

The `examples/` directory contains working code for every feature:

- **`basic_usage.zig`** - Start here for simple logging
- **`context_tracking.zig`** - Request tracking across functions
- **`structured_logging.zig`** - JSON, logfmt, and custom formats
- **`file_rotation.zig`** - Automatic file management
- **`custom_handler.zig`** - Build your own log destinations
- **`json_logging.zig`** - Optimized JSON output
- **`benchmark.zig`** - Performance testing and optimization
- **`time_travel.zig`** - Advanced debugging features
- **`visualization.zig`** - Log analysis and visualization

## Contributing

I welcome contributions of all kinds. Whether it's fixing bugs, adding features, improving documentation, or sharing how you use nexlog in your projects.

Before starting work on a major feature, please open an issue to discuss the approach. This helps ensure your effort aligns with the project's direction and avoids duplicate work.

## License

nexlog is available under the MIT License. See the [LICENSE](./LICENSE) file for the complete text.

---

## 🎯 关于 `zig fetch` 的重要说明

### ❌ 不推荐使用 `zig fetch`

在 Zig 0.16 中，**不再推荐**使用 `zig fetch` 来安装正式依赖：

```bash
# ❌ 不推荐的旧方式
zig fetch --save git+https://github.com/chrischtel/nexlog/
```

### ✅ 推荐的现代方式

**1. 直接在 `build.zig.zon` 中配置依赖：**

```zig
.{
    .name = .my_app,
    .version = "1.0.0",
    .dependencies = .{
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.7.1.tar.gz",
            .hash = "",  // ← 留空，Zig 会自动填充
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

**2. 然后直接构建：**

```bash
zig build

# Zig 会自动：
# ✅ 下载 nexlog-0.7.1.tar.gz
# ✅ 计算 SHA256 hash
# ✅ 更新你的 build.zig.zon
# ✅ 编译你的项目
```

### 🔧 开发和测试场景

如果你正在开发或测试 nexlog 本身，可以使用以下替代方案：

#### 方案 A: 使用本地路径
```zig
.{
    .dependencies = .{
        .nexlog = .{
            .path = "../nexlog",  // 本地相对路径
        },
    },
}
```

#### 方案 B: 测试本地修改
```bash
# 使用你本地修改的 nexlog 版本进行构建
zig build --fork=../nexlog
```

### 📊 三种方式对比

| 场景 | 推荐方式 | 命令 | 说明 |
|------|---------|------|------|
| **生产使用** | `build.zig.zon` 配置 | `zig build` | 标准方式，自动管理依赖 |
| **开发测试** | 本地路径 | `path = "../nexlog"` | 测试正在开发的版本 |
| **临时测试** | Fork 参数 | `--fork=../nexlog` | 测试本地修改 |

### 💡 核心要点

1. **`zig fetch` 主要用于开发阶段**，不推荐用于生产依赖管理
2. **推荐直接在 `build.zig.zon` 中配置**，然后运行 `zig build`
3. **首次构建时会自动下载依赖并填充 hash**
4. **后续构建会使用缓存的依赖**，无需重新下载

---

**总结：对于大多数情况，只需在 `build.zig.zon` 中添加依赖并运行 `zig build` 即可！** 🚀
