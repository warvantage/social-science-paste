# Social Science Paste

<p align="center">
  <img src="Assets/social-science-paste-logo.png" alt="Social Science Paste" width="180">
</p>

**Selective clipboard cleaning for academic writing on macOS.**

Normal paste often keeps too much: fonts, sizes, colours, highlighting and other source styling. Plain-text paste removes too much: it can also remove *italics*, **bold emphasis**, and hyperlinks that still carry meaning in academic writing.

**Social Science Paste lets you choose independently whether to preserve Bold, Italic, and Hyperlinks — in any combination — while removing unwanted presentation styling.**

- **Bold** — on / off
- *Italic* — on / off
- **Hyperlinks** — on / off
- **Pause / Resume** — temporarily leave new copies completely untouched
- **Launch at Login**
- **English / 中文**
- Normal `⌘V` remains the destination app's native paste command
- Clipboard processing stays on your Mac

## Why “Social Science Paste”? 

Academic writing constantly moves text between browsers, AI tools, Word documents, collaborative editors, slides and email. The useful part of formatting is often semantic — an italicised book title, an emphasised phrase, or a citation link — while the copied font, size, colour or highlighting is usually unwanted.

Social Science Paste tries to **preserve meaning while removing presentation**.

## Downloads

### Stable — v1.0.0

General text and rich-text clipboard cleaning with independently selectable Bold / Italic / Hyperlink preservation.

**[Download Social Science Paste v1.0.0](https://github.com/warvantage/social-science-paste/releases/download/v1.0.0/Social-Science-Paste-1.0.0.dmg)**

### Beta — v1.0.1-beta

Includes additional compatibility improvements for text copied from Microsoft Word / Office.

**[Download Social Science Paste v1.0.1-beta](https://github.com/warvantage/social-science-paste/releases/download/v1.0.1-beta/Social-Science-Paste-1.0.1-beta.dmg)**

> These builds are not currently notarised with an Apple Developer ID. If macOS blocks the first launch, go to **System Settings → Privacy & Security → Open Anyway**.

## Current scope

Social Science Paste currently focuses on **text and rich text**. Text content, Unicode and line breaks are preserved. Images, files, PDF objects and structured tables are currently left untouched.

## Privacy

Clipboard processing is local. Social Science Paste does not upload clipboard contents to a server.

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 11 Big Sur or later

---

# 中文介绍

**Social Science Paste 是一个面向学术写作场景的 macOS 轻量级剪贴板格式清理工具。**

普通粘贴往往会保留太多来源格式，例如字体、字号、颜色和高亮；而纯文本粘贴又经常删得太彻底，把论文写作中仍然有意义的 *斜体*、**粗体强调** 和超链接一起删除。

**Social Science Paste 的核心区别是：你可以分别选择是否保留 Bold（粗体）、Italic（斜体）和 Hyperlinks（超链接）。三个选项彼此独立，可以任意组合。**

例如，你可以：

- 只保留斜体
- 只保留粗体
- 只保留超链接
- 保留粗体 + 斜体
- 保留斜体 + 超链接
- 或者三个都不保留

其他来源视觉格式，例如字体、字号、颜色和高亮，则会被清理。

## 为什么叫 Social Science Paste？

它来自一个很具体的社科学术写作痛点：研究者经常需要在网页、AI 工具、Word、协作文档、PPT 和邮件之间移动文字。真正需要留下的往往是“有意义的格式”，例如书名斜体、强调和链接；而来源字体、字号、颜色等通常只是视觉样式。

这个项目希望做到的是：**保留意义，清理呈现。**

## 下载

### 稳定版 — v1.0.0

适用于一般文本和富文本剪贴板清理，并支持独立选择保留粗体、斜体和超链接。

**[下载 Social Science Paste v1.0.0](https://github.com/warvantage/social-science-paste/releases/download/v1.0.0/Social-Science-Paste-1.0.0.dmg)**

### Beta — v1.0.1-beta

进一步增强了从 Microsoft Word / Office 复制文字时的兼容性。

**[下载 Social Science Paste v1.0.1-beta](https://github.com/warvantage/social-science-paste/releases/download/v1.0.1-beta/Social-Science-Paste-1.0.1-beta.dmg)**

## 其他功能

- 菜单栏 Pause / Resume，临时暂停处理新的复制内容
- 登录自动启动
- English / 中文界面
- 继续使用正常的 `⌘V`，不需要额外粘贴快捷键
- 所有剪贴板处理均在本机完成

## Maintainer

Maintained by the Social Science Paste project.

## Licence

Source code in this repository is licensed under the Mozilla Public License 2.0 (MPL-2.0).
