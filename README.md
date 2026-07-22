---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '858f288f-4ab3-4bdd-bcf4-420f09e31e14'
  PropagateID: '858f288f-4ab3-4bdd-bcf4-420f09e31e14'
  ReservedCode1: 'adeb9374-47a9-4172-a49d-4d0249f56828'
  ReservedCode2: 'adeb9374-47a9-4172-a49d-4d0249f56828'
---

# Blender 快捷键查询 (macOS)

轻量级 macOS 桌面应用，用于快速查询 Blender 3.6 ~ 5.2 的快捷键。

## 特性

- **模糊搜索**：支持中文名称、拼音全拼、拼音首字母、快捷键组合多维度搜索
- **分类筛选**：10 大分类一键过滤（通用操作、视图导航、选择操作、变换操作、编辑模式-建模、雕刻模式、UV编辑、着色-节点、动画-绑定、渲染）
- **搜索历史**：自动记录最近 20 条搜索，点击即可复用
- **高亮匹配**：搜索结果中匹配关键词高亮显示
- **全离线**：无需网络连接，所有数据内置于应用

## 截图

应用界面基于 WKWebView 渲染，深色主题，响应式布局。

## 系统要求

- macOS 13.0 (Ventura) 或更高
- Apple Silicon (M 系列芯片)

## 快速开始

### 方式一：直接使用

1. 下载或克隆本仓库
2. 运行 `./build.sh` 编译
3. 打开 `build/BlenderShortcuts.app`

### 方式二：从源码构建

```bash
git clone https://github.com/johnwangxs-art/blender-shortcuts-mac.git
cd blender-shortcuts-mac
./build.sh
open build/BlenderShortcuts.app
```

## 项目结构

```
blender-shortcuts-mac/
├── BlenderShortcuts/
│   ├── AppDelegate.swift      # macOS 应用主逻辑（WKWebView 容器）
│   ├── Info.plist             # 应用元数据
│   └── Resources/
│       └── blender_shortcuts.html  # 快捷键数据 + 搜索引擎 + UI（单文件）
├── build.sh                   # 构建脚本
└── README.md
```

## 搜索示例

| 输入 | 匹配结果 |
|------|---------|
| `挤出` | 挤出（编辑模式） |
| `jc` | 挤出（拼音首字母匹配） |
| `Ctrl+R` | 环切 |
| `tj` | 统计/添加 |
| `旋转` | 旋转（变换操作） |

## 技术细节

- **应用框架**：Swift + AppKit + WebKit（WKWebView）
- **体积**：约 152KB（含全部 134 条快捷键数据）
- **数据源**：内置 134 条快捷键，覆盖 Blender 3.6 ~ 5.2
- **搜索引擎**：三层模糊匹配（精确 → 前缀 → 包含），支持多关键词 AND 查询
- **拼音支持**：131 条拼音映射，支持全拼和首字母缩写

## 许可证

MIT License

> AI生成