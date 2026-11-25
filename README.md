# Fluor4me

简体中文 · [English](#english)

Fluor4me 是一款 macOS 菜单栏工具，可按应用切换功能键模式。在 Google Chrome 中，按 F4 打开或搜索选中的文字，按 F5 复制当前标签页。

## 功能

- **按应用切换功能键**。在菜单栏给各个应用选择标准 F1–F12、亮度和音量等媒体键，或跟随默认模式。可以随前台应用自动切换，也可以设置为短按 Fn 切换当前应用或全局模式。
- **在 Chrome 按 F4 访问或搜索**。在网页中选中 `qq.com` 这样的地址，按受支持的 Mac 内置键盘上的 F4，即可在新标签页访问。选中普通文字时，Chrome 使用当前配置的默认搜索引擎。无痕窗口的结果在原窗口打开。Chrome 中的亮度和音量键仍可照常使用。短按 Fn 和 F4 快捷操作需要在系统设置中授予 Fluor4me 辅助功能权限。
- **在 Chrome 按 F5 复制当前标签页**。授予 Fluor4me 辅助功能权限后，在受支持的 Mac 内置键盘上按 F5，Chrome 会在原窗口打开副本。适用于普通和无痕窗口，支持英文、简体中文和繁体中文 Chrome 菜单。
- **菜单栏管理**。菜单栏图标显示当前模式，可以打开规则、查看运行中的应用，或暂停和恢复键盘管理。

## 安装

下载 [Fluor4me 2.7.0](https://github.com/yjcdon/Fluor4me/releases/tag/v2.7.0) 的 arm64 ZIP。退出旧版，解压后将应用放到个人「应用程序」目录 `~/Applications`。发行包适用于搭载 Apple 芯片并运行 macOS 14 或更新版本的 Mac，采用 ad hoc 临时签名。需要从源码构建时，使用 Python 3 和 macOS Command Line Tools 运行 `./scripts/build-app.py`。

## 2.7.0

F5 使用 Chrome 的原生复制命令，副本保留浏览历史。按住 F5 只复制一次，地址栏无需获得焦点。

## 2.6.2

F4 直接将请求交给运行中的 Chrome，省去启动转发进程的等待。一次只处理一个请求，Chrome 忙时的连按会被忽略。

## 2.6.1

Chrome F4 可以直接打开选中的网址，也可以用当前配置的默认搜索引擎搜索文字。普通窗口和可确认目标的单配置无痕窗口直接打开新标签页，地址栏无需获得焦点。无法确认目标时，Fluor4me 通过原窗口的地址栏提交。

## 2.6.0

- 「设置 → 通用」可以即时切换简体中文和英文，也可以启用登录时启动。「设置 → 关于」可以查看版本和打开项目主页。
- 设置、规则和运行中的应用窗口支持最小化和用 ⌘W 关闭。关闭窗口后仍可从菜单栏使用 Fluor4me。

在 macOS 27 上，解压 ZIP 后，将 Fluor4me 放到个人「应用程序」目录 `~/Applications`。已在 macOS 27.2.1 实测，按住 ⌘ 将图标拖出菜单栏可立即隐藏。在「系统设置 → 菜单栏」打开 Fluor4me，图标会立即回来。

Fluor4me 基于 Pierre Tacchi 的 [Fluor](https://github.com/Pyroh/Fluor)，功能键切换参考了 [fntoggle](https://github.com/nelsonjchen/fntoggle)。[MIT 许可证](LICENSE)

## English

[简体中文](#fluor4me)

Fluor4me is a macOS menu bar utility that switches function-key modes per app. In Google Chrome, press F4 to open a selected address or search selected text, and press F5 to duplicate the current tab.

### Features

- **Per-app function keys.** Use the menu bar to assign standard F1–F12, media keys such as brightness and volume, or the default mode to each app. Switch automatically with the active app, or configure a quick Fn tap to change the current app or global mode.
- **Open or search with F4 in Chrome.** Select an address such as `qq.com` on a web page and press F4 on a supported built-in Mac keyboard to visit it in a new tab. Select ordinary text to search with the current Chrome profile’s default search engine. Results from an Incognito window open in that window. Brightness and volume keys stay available in Chrome. Fn tap and the F4 shortcut require Accessibility permission for Fluor4me in System Settings.
- **Duplicate the current tab with F5 in Chrome.** On a supported built-in Mac keyboard, press F5 once to open a copy in the same regular or Incognito window. This shortcut requires Accessibility permission for Fluor4me and supports English, Simplified Chinese, and Traditional Chinese Chrome menus.
- **Menu bar controls.** The icon shows the active mode. Open rules, view running apps, or pause and resume keyboard management from the menu.

### Installation

Download the arm64 ZIP from [Fluor4me 2.7.0](https://github.com/yjcdon/Fluor4me/releases/tag/v2.7.0). Quit your current copy, unzip the download, and move the app to your personal Applications folder, `~/Applications`. The ad hoc signed release requires an Apple silicon Mac running macOS 14 or later. To build from source, run `./scripts/build-app.py` with Python 3 and macOS Command Line Tools.

### 2.7.0

F5 uses Chrome’s native Duplicate Tab command and preserves browsing history in the copy. Holding F5 creates one copy, and the address bar stays out of focus.

### 2.6.2

F4 sends requests directly to the running Chrome instance. Fluor4me handles one request at a time and discards additional presses while Chrome is busy.

### 2.6.1

F4 opens a selected address or searches the selected text with the current Chrome profile’s default search engine. Results open directly in a new tab in regular windows and in Incognito windows when Chrome has a single identifiable profile. When the destination window is uncertain, Fluor4me submits from the source window’s address bar.

### 2.6.0

- Use Settings → General to switch instantly between Simplified Chinese and English or enable launch at login. Settings → About shows the version and links to the project.
- Minimize the Settings, Rules, and Running Applications windows or close them with ⌘W. Fluor4me stays available in the menu bar.

On macOS 27, unzip the release and move Fluor4me to your personal Applications folder, `~/Applications`. On macOS 27.2.1, Command-dragging the icon out of the menu bar hides it immediately. Turning on Fluor4me in System Settings → Menu Bar restores it immediately.

Fluor4me is based on Pierre Tacchi’s [Fluor](https://github.com/Pyroh/Fluor) and draws on [fntoggle](https://github.com/nelsonjchen/fntoggle) for function-key switching. [MIT License](LICENSE)
