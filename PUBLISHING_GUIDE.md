# Zig 模块发布指南

## 📦 如何引用 nexlog

### 方式 1: 通过 Git URL (推荐)

在其他项目的 `build.zig.zon` 中添加：

```zig
.{
    .name = .my_project,
    .version = "1.0.0",
    .dependencies = .{
        .nexlog = .{
            .url = "https://github.com/zhangfisher/nexlog/archive/refs/tags/v0.7.1.tar.gz",
            .hash = "", // 运行 `zig build` 后会自动填充
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

### 方式 2: 使用本地路径 (开发中)

```zig
.{
    .name = .my_project,
    .version = "1.0.0",
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

### 方式 3: 使用 `--fork` 临时覆盖

```bash
# 测试本地修改的 nexlog 版本
zig build --fork=../nexlog
```

### 方式 4: 通过 Zig 包管理器 (未来)

```bash
# 一旦 Zig 包管理器支持，可以使用：
# zig package add nexlog --url=https://github.com/yourusername/nexlog
```

## 🔧 在代码中使用 nexlog

### 在 `build.zig` 中添加模块

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 导入 nexlog 模块
    const nexlog = b.dependency("nexlog", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my_app",
        .root_source_file = b.path("src/main.zig"),
    });

    // 添加 nexlog 依赖
    exe.root_module.addImport("nexlog", nexlog.module("nexlog"));
    b.installArtifact(exe);
}
```

### 在应用代码中使用

```zig
const std = @import("std");
const nexlog = @import("nexlog");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 初始化日志系统
    try nexlog.init(allocator);
    defer nexlog.deinit();

    const logger = nexlog.getDefaultLogger();
    
    logger.info("Application started", .{}, nexlog.here(@src()));
    logger.err("This is an error", .{}, nexlog.here(@src()));
}
```

## 📋 发布检查清单

### 必需文件
- [x] `build.zig.zon` - 包配置
- [x] `build.zig` - 构建脚本  
- [x] `src/nexlog.zig` - 模块入口
- [ ] `README.md` - 使用说明
- [ ] `LICENSE` - 开源协议

### 推荐文件
- [ ] `CHANGELOG.md` - 版本变更记录
- [ ] `examples/` - 使用示例
- [ ] `tests/` - 测试用例

### 版本管理
```bash
# 更新版本号时
1. 修改 build.zig.zon 中的 .version
2. 更新 .fingerprint (运行 `zig build` 会提示)
3. 创建 Git 标签
4. 推送到 GitHub
```

## 🎯 发布流程

### 1. 准备发布

```bash
# 确保工作目录干净
git status

# 更新版本号
# 编辑 build.zig.zon，设置新版本号

# 运行测试确保一切正常
zig build test
zig build all-examples
```

### 2. 创建发布标签

```bash
# 提交所有更改
git add .
git commit -m "Release v0.7.1"

# 创建标签
git tag -a v0.7.1 -m "Release v0.7.1 - Zig 0.16.0 support"
git push origin main --tags
```

### 3. 验证发布

```bash
# 在新项目中测试
mkdir test_nexlog_usage
cd test_nexlog_usage
zig init-exe

# 编辑 build.zig.zon 添加 nexlog 依赖
# zig build 会自动下载并缓存依赖
```

## 🔍 模块版本发现

其他用户可以通过以下方式发现你的模块：

1. **GitHub 搜索** - 搜索 "zig logging library"
2. **Zig Package Registry** (未来)
3. **社区推荐** - 在 Zig 官方论坛分享

## 📊 依赖管理

### 依赖缓存

Zig 会将下载的依赖缓存到全局目录：
- Windows: `%LOCALAPPDATA%\zig`
- Linux/Mac: `~/.cache/zig`

### 依赖更新

```bash
# 强制重新下载依赖
zig build --fetch

# 清除缓存重新构建
zig build -f
```

## 🎓 最佳实践

1. **语义化版本** - 遵循 SemVer 规范
2. **文档完整** - 提供清晰的 API 文档和示例
3. **兼容性** - 明确支持的 Zig 版本
4. **测试覆盖** - 确保核心功能有测试
5. **发布说明** - 每个版本都有详细的变更说明

## 🚀 推广建议

1. **在 Zig 官方论坛发布**
2. **在 Reddit r/Zig 分享**
3. **编写博客文章介绍你的库**
4. **在 GitHub 上 trending 标签中提及**
5. **与其他 Zig 开发者交流**

---

**你的 nexlog 项目已经准备好发布！** 🎉
