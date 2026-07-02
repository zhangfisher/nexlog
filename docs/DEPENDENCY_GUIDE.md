# Zig 依赖管理完整指南

## 🔍 Hash 填充机制详解

### 自动填充过程演示

#### 步骤 1: 初始配置
```zig
// build.zig.zon
.{
    .name = .my_app,
    .version = "1.0.0",
    .dependencies = .{
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.7.1.tar.gz",
            .hash = "",  // 留空，让 Zig 自动填充
        },
    },
}
```

#### 步骤 2: 首次构建
```bash
$ zig build

# 输出显示：
nexlog ... fetch
Downloading nexlog...
Computing hash...
Updating build.zig.zon
```

#### 步骤 3: 自动更新后
```zig
// build.zig.zon (Zig 自动更新)
.{
    .name = .my_app,
    .version = "1.0.0",
    .dependencies = .{
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.7.1.tar.gz",
            .hash = "1220abcdef1234567890abcdef1234567890abcdef1234567890ab", // 自动填充
        },
    },
}
```

## 📂 缓存目录结构

### Windows
```
C:\Users\<用户>\AppData\Local\zig\
├── zig-pkg\                          # 全局下载的依赖包
│   ├── github.com\
│   │   └── chrischtel\
│   │       └── nexlog-<hash>\
│   │           └── nexlog-<version>.tar.gz
└── zig-cache\                        # 项目特定缓存
    └── o\<随机ID>\
        └── import\
            └── nexlog\
```

### Linux/Mac
```
~/.cache/zig/
├── zig-pkg/                          # 全局下载的依赖包
│   ├── github.com/
│   │   └── chrischtel/
│   │       └── nexlog-<hash>\
│   │           └── nexlog-<version>.tar.gz
└── zig-cache/                        # 项目特定缓存
    └── o/<random-id>/
        └── import/
            └── nexlog/
```

## 🔧 手动获取 Hash

### 方法 1: 使用 Zig 命令行工具
```bash
# 下载并计算 hash
wget https://github.com/chrischtel/nexlog/archive/refs/tags/v0.7.1.tar.gz
sha256sum nexlog-0.7.1.tar.gz

# 或者使用 Zig 内置工具
zig fetch
# 检查输出信息，会显示计算的 hash
```

### 方法 2: 查看已缓存的依赖
```bash
# Windows
dir "%LOCALAPPDATA%\zig\zig-pkg\"

# Linux/Mac
ls ~/.cache/zig/zig-pkg/

# 查看项目配置
cat build.zig.zon | grep -A2 nexlog
```

## ⚠️ Hash 不匹配错误

### 错误示例
```bash
$ zig build

error: hash mismatch: expected 1220abcdef... but found abcd1234...
Build failed because dependency hash verification failed.
```

### 解决方法
```bash
# 1. 清除特定依赖缓存
rm -rf ~/.cache/zig/zig-pkg/<package-name>

# 2. 或重新获取依赖
zig build --fetch

# 3. 或使用 --refresh 标志
zig build --refresh
```

## 🎯 最佳实践

### 1. 开发阶段使用路径
```zig
.{
    .dependencies = .{
        .nexlog = .{
            .path = "../nexlog",  // 开发时使用本地路径
        },
    },
}
```

### 2. 发布时使用固定版本
```zig
.{
    .dependencies = .{
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.7.1.tar.gz",
            .hash = "1220abcdef...",  // 使用具体的 hash
        },
    },
}
```

### 3. 版本管理建议
- ✅ 使用具体的 Git 标签版本
- ✅ 在 `CHANGELOG.md` 中记录版本变更
- ✅ 提供 migration guide（如果有破坏性更新）
- ✅ 保持向后兼容性

## 📊 依赖管理命令

### 常用命令
```bash
# 获取所有依赖
zig build --fetch

# 强制重新下载依赖
zig build --refresh

# 查看依赖树
zig build --fetch

# 清理项目缓存
rm -rf zig-cache/

# 清理全局缓存
rm -rf ~/.cache/zig/zig-pkg/  # Linux/Mac
rm -rf "%LOCALAPPDATA%\zig\zig-pkg"  # Windows
```

## 🔄 更新依赖流程

### 更新到新版本
```zig
// 1. 更新 build.zig.zon
.{
    .dependencies = .{
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.8.0.tar.gz",
            .hash = "",  // 新版本，留空让 Zig 自动填充
        },
    },
}

// 2. 强制重新获取
zig build --refresh

// 3. 检查更新后的 build.zig.zon
cat build.zig.zon | grep -A2 nexlog
```

## 🔍 故障排除

### 常见问题

#### 1. Hash 填充后项目仍然失败
```bash
# 检查实际下载的包内容
ls ~/.cache/zig/zig-pkg/  # Linux/Mac
dir %LOCALAPPDATA%\zig\zig-pkg  # Windows

# 手动验证 hash
sha256sum <downloaded-file>
```

#### 2. 权限问题
```bash
# 确保缓存目录可写
chmod +w ~/.cache/zig/zig-pkg/
```

#### 3. 网络问题
```bash
# 如果下载失败，可以手动下载
wget <url>
# 然后放到缓存目录
```

## 📝 实际例子

### nexlog 依赖示例
```zig
.{
    .name = .awesome_app,
    .version = "1.0.0",
    .dependencies = .{
        // 使用 GitHub 发布版本
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.7.1.tar.gz",
            .hash = "",  // 首次构建时自动填充
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

---

**总结：Zig 0.16 的依赖管理系统会自动处理 hash 计算和依赖下载，你只需要留空 hash 字段即可！**
