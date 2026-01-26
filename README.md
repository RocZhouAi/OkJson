# OkJson

🚀 一款轻量、高性能的 macOS 原生 JSON 格式化与比较工具。

![Platform](https://img.shields.io/badge/Platform-macOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ 功能特性

### 📝 JSON 格式化
- **智能格式化** - 自动检测并格式化 JSON，支持自定义缩进
- **语法高亮** - 清晰的颜色区分键、值、数组等元素
- **行号显示** - 方便快速定位
- **大文件支持** - 流式解析，轻松处理大型 JSON 文件

### 🔍 JSON 比较
- **双栏对比** - 并排显示两个 JSON 的差异
- **树形视图** - 折叠/展开节点，聚焦关注区域
- **差异高亮** - 一眼识别新增、删除、修改的内容
- **键排序** - 自动按键名排序，方便比较

### ⚡ 性能优化
- **原生 AppKit** - 纯 Swift + AppKit 实现，流畅无卡顿
- **内存高效** - 索引解析机制，低内存占用
- **响应迅速** - 即使处理大文件也保持 UI 流畅

## 📦 安装

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/RocZhouAi/OkJson.git
cd OkJson

# 使用 Xcode 打开
open OkJson.xcodeproj

# 或使用命令行构建
make build
```

### 系统要求
- macOS 13.0+
- Xcode 15.0+ (开发)

## 🚀 使用方法

1. **格式化 JSON**
   - 粘贴或输入 JSON 到左侧编辑区
   - 自动格式化并显示树形结构

2. **比较 JSON**
   - 切换到 Compare 标签
   - 在左右两侧分别粘贴要比较的 JSON
   - 差异会自动高亮显示

## 🛠️ 技术栈

- **语言**: Swift 5.9+
- **框架**: AppKit, Foundation
- **架构**: MVVM
- **测试**: XCTest

## 📁 项目结构

```
OkJson/
├── Models/           # 数据模型
├── Views/            # 视图控制器
├── ViewModels/       # 视图模型
├── Services/         # JSON 解析/格式化服务
└── Utilities/        # 工具类和扩展
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件
