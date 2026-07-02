# NexLog 中的结构化日志

NexLog 提供强大的结构化日志功能，允许您在日志条目中包含丰富的、类型安全的数据。本文档解释如何在应用程序中使用结构化日志。

## 概述

结构化日志允许您在日志消息中包含额外的上下文，格式便于日志聚合工具解析。NexLog 支持多种输出格式：

- **JSON**：标准 JSON 格式，具有最大的兼容性
- **Logfmt**：键=值格式，便于人类阅读和解析
- **自定义**：可配置的格式，支持自定义分隔符

## 基本用法

### 创建结构化字段

```zig
// 创建结构化字段
const fields = [_]format.StructuredField{
    .{
        .name = "user_id",
        .value = .{ .string = "12345" },
        .attributes = null,
    },
    .{
        .name = "request_duration_ms",
        .value = .{ .integer = 150 },
        .attributes = null,
    },
    .{
        .name = "tags",
        .value = .{ .array = &[_]format.FieldValue{
            .{ .string = "api" },
            .{ .string = "v2" },
        }},
        .attributes = null,
    },
};
```

### 支持的字段类型

NexLog 支持多种字段类型：

- **字符串**：文本值
- **整数**：64 位有符号整数
- **浮点数**：64 位浮点数
- **布尔值**：真/假值
- **数组**：值列表
- **对象**：嵌套的键值结构
- **空值**：显式的空值

### 格式化选项

您可以使用不同的选项配置格式化器：

```zig
// JSON 格式
const json_config = format.FormatConfig{
    .structured_format = .json,
    .include_timestamp_in_structured = true,
    .include_level_in_structured = true,
};

// Logfmt 格式
const logfmt_config = format.FormatConfig{
    .structured_format = .logfmt,
    .include_timestamp_in_structured = true,
    .include_level_in_structured = true,
};

// 自定义格式
const custom_config = format.FormatConfig{
    .structured_format = .custom,
    .include_timestamp_in_structured = true,
    .include_level_in_structured = true,
    .custom_field_separator = " | ",
    .custom_key_value_separator = ": ",
};
```

## 示例

### JSON 输出

```json
{"timestamp":1234567890,"level":"INFO","message":"访问用户资料","user_id":"12345","request_duration_ms":150,"tags":["api","v2"]}
```

### Logfmt 输出

```
timestamp=1234567890 level=INFO msg="访问用户资料" user_id=12345 request_duration_ms=150 tags=[api,v2]
```

### 自定义格式输出

```
timestamp: 1234567890 | level: INFO | msg: 访问用户资料 | user_id: 12345 | request_duration_ms: 150 | tags: [api, v2]
```

## 高级功能

### 嵌套结构

您可以在结构化日志中包含嵌套的对象和数组：

```zig
// 创建嵌套对象
var user_data = std.StringHashMap(format.FieldValue).init(allocator);
defer user_data.deinit();
try user_data.put("id", .{ .string = "12345" });
try user_data.put("name", .{ .string = "张三" });
try user_data.put("age", .{ .integer = 30 });
try user_data.put("active", .{ .boolean = true });

// 创建带嵌套结构的结构化字段
const fields = [_]format.StructuredField{
    .{
        .name = "user",
        .value = .{ .object = user_data },
        .attributes = null,
    },
    // ... 其他字段
};
```

### 字段属性

您可以为字段添加额外的属性以提供更多上下文：

```zig
// 创建带属性的段
var attrs = std.StringHashMap([]const u8).init(allocator);
try attrs.put("source", "database");
try attrs.put("format", "uuid");

const field = format.StructuredField{
    .name = "user_id",
    .value = .{ .string = "12345" },
    .attributes = attrs,
};
```

## 与日志记录器集成

您可以与主日志记录器集成结构化日志：

```zig
// 创建格式化器
var formatter = try format.Formatter.init(allocator, config);
defer formatter.deinit();

// 格式化结构化日志条目
const formatted = try formatter.formatStructured(
    .info,
    "访问用户资料",
    &fields,
    metadata,
);
defer allocator.free(formatted);

// 记录格式化的条目
log.info("{s}", .{formatted}, metadata);
```

## 最佳实践

1. **使用有意义的字段名**：选择描述性名称，清楚地表明数据代表什么。
2. **包含上下文**：添加相关上下文，如用户 ID、请求 ID 和时间戳。
3. **保持一致**：在整个应用程序中使用一致的字段名和类型。
4. **保持简单**：不要过度复杂化日志结构 - 专注于最重要的信息。
5. **考虑性能**：对于大量日志，请注意内存分配和字符串格式化。
