# 自定义格式化

NexLog 提供灵活的格式化选项，让您自定义日志的显示方式。您可以使用内置模板或创建自己的模板。

## 模板占位符

日志模板的可用占位符：

| 占位符 | 描述 | 示例 |
|-------------|-------------|---------|
| `{timestamp}` | Unix 时间戳 | `1640995200` |
| `{level}` | 日志级别 | `INFO` |
| `{message}` | 日志消息 | `用户已登录` |
| `{file}` | 源文件名 | `main.zig` |
| `{line}` | 源行号 | `42` |
| `{function}` | 函数名 | `handleRequest` |
| `{thread_id}` | 线程标识符 | `12345` |
| `{hostname}` | 系统主机名 | `server-01` |

## 默认模板

NexLog 附带几个内置模板：

### 标准格式
```
{timestamp} [{level}] [{file}:{line}] {message}
```
输出：`1640995200 [INFO] [main.zig:42] 应用程序启动`

### 紧凑格式
```
{level}: {message}
```
输出：`INFO: 应用程序启动`

### 详细格式
```
{timestamp} [{level}] {hostname} {function}() {file}:{line} - {message}
```
输出：`1640995200 [INFO] server-01 main() main.zig:42 - 应用程序启动`

## 自定义模板

定义您自己的日志格式：

```zig
const config = nexlog.LogConfig{
    .custom_template = "[{level}] {message} (来自 {function})",
};
```

输出：`[INFO] 用户已登录 (来自 handleLogin)`

## 时间戳格式

配置时间戳显示：

```zig
const config = nexlog.LogConfig{
    .timestamp_format = .iso8601, // ISO8601 格式
    // 或 .unix 表示 Unix 时间戳（默认）
};
```

ISO8601 输出：`[2022-01-01T00:00:00Z] [INFO] 应用程序启动`

## 日志级别格式

自定义日志级别的显示方式：

```zig
const config = nexlog.LogConfig{
    .level_format = .upper, // INFO, WARN, ERROR
    // .lower,              // info, warn, error  
    // .short_upper,        // INF, WRN, ERR
    // .short_lower,        // inf, wrn, err
};
```

## 颜色

启用彩色输出以提高可读性：

```zig
const config = nexlog.LogConfig{
    .enable_colors = true,
    .color_scheme = .default, // 或 .dark, .light
};
```

颜色映射：
- TRACE：灰色
- DEBUG：青色  
- INFO：绿色
- WARN：黄色
- ERROR：红色
- CRITICAL：亮红色

## 高级格式化

### 条件格式化

某些占位符是可选的，如果数据不可用则不会显示：

```zig
// 如果未提供元数据，file/line/function 不会显示
const template = "{timestamp} [{level}] {file?}:{line?} {message}";
```

### 字段宽度和对齐

控制字段外观：

```zig
// 在 8 个字符中右对齐级别
const template = "{timestamp} [{level:>8}] {message}";
```

输出：`1640995200 [    INFO] 应用程序启动`

### 转义

使用双括号包含字面量括号：

```zig
const template = "{{level}}: {message}"; 
```

输出：`{level}: 应用程序启动`

## JSON 格式化

对于结构化输出，启用 JSON 格式化：

```zig
const config = nexlog.LogConfig{
    .output_format = .json,
    .include_metadata = true,
};
```

输出：
```json
{"timestamp":1640995200,"level":"INFO","file":"main.zig","line":42,"message":"应用程序启动"}
```

## 性能考虑

- 简单模板比复杂模板更快
- 在高频日志中避免使用昂贵的占位符，如 `{hostname}`
- 使用缓冲输出以获得更好的性能
- 考虑在生产环境中禁用颜色

## 模板验证

NexLog 在初始化时验证模板：

```zig
// 这将返回错误
const bad_config = nexlog.LogConfig{
    .custom_template = "{invalid_placeholder} {message}",
};
const logger = nexlog.Logger.init(allocator, bad_config); // 错误！
```

## 示例

### Web 服务器日志
```zig
const template = "{timestamp} [{level}] {method} {url} {status_code} {response_time}ms";
```

### 调试日志
```zig  
const template = "[{level}] {function}() 在 {file}:{line} - {message}";
```

### 生产环境日志
```zig
const template = "{timestamp} {level} {message}";
```
