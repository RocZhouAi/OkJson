# OkJson

一款轻量、高性能的 macOS 原生 JSON 格式化工具，支持多列并排查看。

![Platform](https://img.shields.io/badge/Platform-macOS_13+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## 功能特性

### JSON 格式化与树形展示
- **粘贴即格式化** - 粘贴 JSON 后自动解析并以树形结构展示
- **语法着色** - 键、字符串、数值、布尔值、null 分别着色
- **行号显示** - 可在底栏开关
- **括号高亮** - 选中容器节点时自动高亮匹配的开闭括号
- **键排序** - 按字母序排列 JSON Key（底栏切换）
- **缩进设置** - 支持 2 / 4 空格缩进
- **节点操作** - 右键菜单可复制 Key / Value / Key-Value / 整段 JSON，也可删除节点

### 多列工作区
- **动态添加列** - `⌘D` 添加新列，可同时查看多个 JSON
- **同步滚动** - 多列模式下底栏可开启同步滚动
- **自动均分列宽** - 窗口 resize 时列宽自动均分
- **智能适应列宽** - `⌘⇧W` 根据焦点列内容自动调整宽度
- **列头管理** - 每列带标题和颜色标记，支持关闭按钮

### 性能
- **原生 AppKit** - 纯 Swift + AppKit 实现，无第三方依赖
- **索引解析** - 零拷贝索引式解析，低内存占用
- **懒加载** - 超过 50 个子项的大容器按需加载

### 其他
- **主题切换** - 底栏一键切换亮色 / 暗色主题
- **打开文件** - 支持 `.json` 和 `.xcs` 文件
- **大文件** - 支持最大 10 MB 文件

## 安装

### 从源码构建

```bash
git clone https://github.com/RocZhouAi/OkJson.git
cd OkJson

# 构建并启动 .app
make app

# 或仅构建
make build
```

### 系统要求
- macOS 13.0+
- Xcode 15.0+（开发）

## 使用方法

1. **格式化 JSON** - 启动后 `⌘V` 粘贴 JSON，自动解析为树形视图
2. **多列对比** - `⌘D` 添加新列，在不同列中分别粘贴 JSON 并排查看
3. **复制节点** - 右键点击树中节点，可复制 Key、Value 或整段 JSON
4. **删除节点** - 选中节点后按 `Delete` 键或右键选择"删除"

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘V` | 粘贴 JSON |
| `⌘R` | 格式化 |
| `⌘D` | 添加列 |
| `⌘⇧W` | 自动适应列宽 |
| `⌘⇧V` | 粘贴 JSON（菜单） |
| `⌘⇧C` | 复制格式化结果 |
| `⌘⇧S` | 键排序 |
| `⌘K` | 清空输入 |
| `⌘O` | 打开文件 |

## 技术栈

- **语言**: Swift 5.9+
- **框架**: AppKit, Foundation
- **架构**: MVVM
- **构建**: Swift Package Manager
- **测试**: XCTest

## 项目结构

```
OkJson/
├── Models/           # 数据模型（JSON 节点、Diff、格式偏好等）
├── Views/            # AppKit 视图与控制器
├── ViewModels/       # 视图模型
├── Services/         # JSON 解析、格式化、剪贴板服务
├── Utilities/        # 常量、主题、颜色方案、扩展
└── Resources/        # 资源文件（Assets、示例 JSON 等）
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件
