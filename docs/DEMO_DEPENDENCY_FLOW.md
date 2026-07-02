# 依赖管理流程演示

## 🎭 角色分工演示

### 角色 A: nexlog 库作者 (你)
```bash
# 1. 你发布 nexlog v0.7.1
cd nexlog
vim build.zig.zon  # 更新版本号
git tag -a v0.7.1 -m "Release"
git push origin main --tags
```

### 角色 B: 应用开发者 (使用 nexlog)
```bash
# 2. 他们创建新项目
mkdir my_awesome_app
cd my_awesome_app
zig init-exe

# 3. 编辑 build.zig.zon 添加 nexlog 依赖
vim build.zig.zon  # 添加 nexlog 依赖，hash 留空

# 4. 首次构建 (这里发生 hash 自动填充!)
zig build

# Zig 自动执行：
# - 下载 nexlog-0.7.1.tar.gz
# - 计算 hash
# - 更新 build.zig.zon
# - 编译项目
```

## 📝 实际例子对比

### nexlog 项目 (库作者)
```zig
// build.zig.zig - 你维护这个
.{
    .name = .nexlog,
    .fingerprint = 0xc1b0e10c4c3f3cd,
    .version = "0.7.1",  // ← 你更新版本号
    .dependencies = .{},
    .paths = .{
        "build.zig",
        "src",
    },
}
```

### 第三方应用 (使用者)
```zig
// build.zig.zig - 他们编辑这个
.{
    .name = .my_app,
    .version = "1.0.0",
    .dependencies = .{
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.7.1.tar.gz",
            .hash = "",  // ← 他们留空
        },
    },
}

# 他们首次运行 `zig build` 后
# Zig 自动更新为：
.{
    .name = .my_app,
    .version = "1.0.0",
    .dependencies = .{
        .nexlog = .{
            .url = "https://github.com/chrischtel/nexlog/archive/refs/tags/v0.7.1.tar.gz",
            .hash = "1220abcdef1234567890abcdef1234567890abcdef1234567890ab",  // ← 自动填充
        },
    },
}
```

## 🔍 验证步骤

### 作为库作者 (你)
```bash
# 你只需要：
1. 确保 build.zig.zon 正确配置
2. 创建 Git 标签
3. 推送到 GitHub

# 不需要你提供 hash！
```

### 作为使用者 (第三方开发者)
```bash
# 他们只需要：
1. 在 build.zig.zon 添加依赖，hash 留空
2. 运行 zig build

# Zig 会自动：
- 下载依赖
- 计算 hash
- 更新他们的 build.zig.zon
```

## 🎯 关键要点

1. **hash 填充发生在使用者的项目中**
   - 不是在 nexlog 项目中
   - 不是在 nexlog 构建时
   - 是在第三方应用首次构建时

2. **你作为库作者不需要手动计算 hash**
   - 只需发布 Git 标签
   - 使用者会自动获取正确的 hash

3. **每个项目都有自己的 build.zig.zon**
   - nexlog 的 build.zig.zig 用于 nexlog 自己的依赖管理
   - 第三方应用的 build.zig.zig 用于管理他们的依赖（包括 nexlog）

## 📱 可视化流程

```
┌─────────────────┐
│ nexlog 作者 (你)  │
└─────────────────┘
         │
         │ git push --tags
         ▼
┌─────────────────┐
│ GitHub 仓库      │
│  └─ v0.7.1.tar.gz │
└─────────────────┘
         │
         │ 第三方应用添加依赖
         ▼
┌─────────────────┐
│ 第三方应用项目   │
│  build.zig.zon:  │
│  nexlog.hash="" │
└─────────────────┘
         │
         │ 首次运行 zig build
         ▼
┌─────────────────┐
│ Zig 自动:        │
│ 1. 下载 .tar.gz │
│ 2. 计算 hash     │
│ 3. 更新 .zon 文件 │
└─────────────────┘
```

---

**总结：hash 自动填充完全发生在使用者的项目中，你作为库作者只需要确保正确的 Git 标签和 URL 可访问性。** 🎉
