# Fluor4me

简体中文 · [English](#english)

Fluor4me 是一款 macOS 菜单栏工具，可按应用切换功能键模式。在 Google Chrome 中，按 F4 访问选中的网址或搜索选中的文字，按 F5 复制当前标签页并保留浏览历史。

[下载 Fluor4me 2.7.0](https://github.com/yjcdon/Fluor4me/releases/tag/v2.7.0) · [版本复盘](docs/versions/README.md)

## 功能

- **按应用切换功能键**。在菜单栏给各个应用选择标准 F1–F12、亮度和音量等媒体键，或跟随默认模式。可以随前台应用自动切换，也可以设置为短按 Fn 切换当前应用或全局模式。
- **在 Chrome 按 F4 访问或搜索**。选中网址，按受支持的 Mac 内置键盘上的 F4，即可在新标签页访问。选中普通文字时，Chrome 使用当前配置的默认搜索引擎。无痕结果留在原窗口，亮度和音量键照常使用。
- **在 Chrome 按 F5 复制当前标签页**。副本留在原窗口并保留浏览历史，长按只复制一次。适用于普通和无痕窗口，支持英文、简体中文和繁体中文 Chrome 菜单。
- **菜单栏管理**。查看当前模式，编辑规则，或暂停和恢复键盘管理。在「设置 → 通用」切换简体中文与英文，或启用登录时启动。

## 安装

发行包适用于搭载 Apple 芯片并运行 macOS 14 或更新版本的 Mac，采用 ad hoc 临时签名。

1. 下载 arm64 ZIP 并退出正在运行的旧版。
2. 解压，将 Fluor4me.app 放到个人「应用程序」目录 `~/Applications` 后打开。
3. 在「系统设置 → 隐私与安全性 → 辅助功能」允许 Fluor4me，以启用短按 Fn 和 Chrome 的 F4、F5 快捷键。

在 macOS 27 上，按住 ⌘ 将图标拖出菜单栏可以隐藏它。打开「系统设置 → 菜单栏」可恢复显示。

## 开发

使用 Python 3 和 macOS Command Line Tools 运行 `./scripts/build-app.py`。回归测试步骤见[项目测试 Skill](skills/fluor4me-regression/SKILL.md)。

Fluor4me 基于 Pierre Tacchi 的 [Fluor](https://github.com/Pyroh/Fluor)，功能键切换参考了 [fntoggle](https://github.com/nelsonjchen/fntoggle)。[MIT 许可证](LICENSE)

## English

[简体中文](#fluor4me)

Fluor4me is a macOS menu bar utility that switches function-key modes per app. In Google Chrome, press F4 to open a selected address or search selected text. Press F5 to duplicate the current tab and keep its browsing history.

[Download Fluor4me 2.7.0](https://github.com/yjcdon/Fluor4me/releases/tag/v2.7.0) · [Version history (Chinese)](docs/versions/README.md)

### Features

- **Per-app function keys.** Use the menu bar to assign standard F1–F12, media keys such as brightness and volume, or the default mode to each app. Switch automatically with the active app, or configure a quick Fn tap to change the current app or global mode.
- **Open or search with F4 in Chrome.** Select an address and press F4 on a supported built-in Mac keyboard to open it in a new tab. Select text to search with the current Chrome profile’s default search engine. Incognito results stay in the source window, and brightness and volume keys stay available.
- **Duplicate the current tab with F5 in Chrome.** The copy opens in the same regular or Incognito window and keeps its browsing history. Holding F5 creates one copy. Supports English, Simplified Chinese, and Traditional Chinese Chrome menus.
- **Menu bar controls.** See the active mode, edit rules, or pause and resume keyboard management. Use Settings → General to switch languages or enable launch at login.

### Installation

The ad hoc signed release requires an Apple silicon Mac running macOS 14 or later.

1. Download the arm64 ZIP and quit your current copy.
2. Unzip the download, move Fluor4me.app to your personal Applications folder at `~/Applications`, and open it.
3. Enable Fluor4me in System Settings → Privacy & Security → Accessibility to use Fn tap and the F4 and F5 shortcuts in Chrome.

On macOS 27, Command-drag the icon out of the menu bar to hide it. Use System Settings → Menu Bar to show it again.

### Development

Run `./scripts/build-app.py` with Python 3 and macOS Command Line Tools. See the [project regression skill (Chinese)](skills/fluor4me-regression/SKILL.md) for test cases and sample pages.

Fluor4me is based on Pierre Tacchi’s [Fluor](https://github.com/Pyroh/Fluor) and draws on [fntoggle](https://github.com/nelsonjchen/fntoggle) for function-key switching. [MIT License](LICENSE)
