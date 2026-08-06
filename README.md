# Legado iPad

SwiftUI 原生 iPad 客户端（[bingoinau-lgtm/legado-ipad](https://github.com/bingoinau-lgtm/legado-ipad)）。

一期采用 **伴侣模式**：iPad 连接同一局域网内 Android「阅读」App 的 Web 服务（默认 `http://手机IP:1122`），同步书架并阅读。

参考实现：本地 `../legado`（Jingshiro/legado 共享源仓）。

## 环境

- macOS + Xcode 16+
- **仅 iPad**（真机或模拟器；真机连手机时需同一 Wi‑Fi）
- 手机端开启阅读 Web 服务

## 打开工程

```bash
cd /Users/bingo/Documents/Legado/legado-ipad
# 若修改了 project.yml，重新生成：
# /path/to/xcodegen generate
open LegadoiPad.xcodeproj
```

在 Xcode 中选择目标设备 → Run。

## 当前功能（MVP）

- **书源（无需手机）**：从 JSON 网址导入书源 → 搜索/分类 → 目录 → 正文（已用「五八书阁」验证规则引擎 MVP）
- **本机订阅（无需手机）**：添加网上 RSS / Atom 地址，拉取文章列表并用内置浏览器阅读
- 配置手机 IP / 端口并测试连接（书架仍依赖手机 Web 服务）
- 拉取书架、搜索、下拉刷新
- 打开书籍：目录、正文、上一章/下一章
- 自动回写阅读进度到手机（`/saveBookProgress`）
- 连接手机后可查看手机上的「规则订阅源」列表

## 目录

```
LegadoiPad/
  App/           # 根导航与全局状态
  Core/          # API 模型与网络客户端
  Features/      # 连接 / 书架 / 阅读
```

## 后续方向

- 单机模式（本地书 / 书源解析）
- 想法批注、阅读记录、AI 助手等增强能力
- UI 针对 iPad 分栏与键盘进一步打磨

## 许可

GPL-3.0（与上游阅读项目对齐，完整 LICENSE 稍后补齐）。
