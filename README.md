# Fluor4me

简体中文 · [English](#english)

Fluor4me 是一款 macOS 菜单栏工具，可按应用切换功能键模式，也能在 Google Chrome 中按 F4 搜索网页选中的文字。

## 功能

- **按应用切换功能键**。在菜单栏给各个应用选择标准 F1–F12、亮度和音量等媒体键，或跟随默认模式。可以随前台应用自动切换，也可以设置为短按 Fn 切换当前应用或全局模式。
- **在 Chrome 按 F4 搜索**。在网页中选中文字，按受支持的 Mac 内置键盘上的 F4，即可在新标签页打开 Google 搜索。Chrome 中的亮度和音量键仍可照常使用。短按 Fn 和 F4 搜索需要在系统设置中授予 Fluor4me 辅助功能权限。
- **菜单栏管理**。菜单栏图标显示当前模式，可以打开规则、查看运行中的应用，或暂停和恢复键盘管理。

## 2.6.0

- 「设置 → 一般」可以即时切换简体中文和英文，也可以启用登录时启动。「设置 → 关于」可以查看版本和打开项目主页。
- 设置、规则和运行中的应用窗口支持最小化和用 ⌘W 关闭。关闭窗口后仍可从菜单栏使用 Fluor4me。
- 支持 Apple 芯片 Mac，要求 macOS 14 或更新版本。使用 Python 3 和 macOS Command Line Tools 运行 `./scripts/build-app.py`，生成 `dist/Fluor4me.app`。

Fluor4me 基于 Pierre Tacchi 的 [Fluor](https://github.com/Pyroh/Fluor)，功能键切换参考了 [fntoggle](https://github.com/nelsonjchen/fntoggle)。[MIT 许可证](LICENSE)

## English

[简体中文](#fluor4me)

Fluor4me is a macOS menu bar utility that switches function-key modes per app and uses F4 to search selected text in Google Chrome.

### Features

- **Per-app function keys.** Use the menu bar to assign standard F1–F12, media keys such as brightness and volume, or the default mode to each app. Switch automatically with the active app, or configure a quick Fn tap to change the current app or global mode.
- **F4 search in Chrome.** Select text on a web page and press F4 on a supported built-in Mac keyboard to open a Google search in a new tab. Brightness and volume keys stay available in Chrome. Fn tap and F4 search require Accessibility permission for Fluor4me in System Settings.
- **Menu bar controls.** The icon shows the active mode. Open rules, view running apps, or pause and resume keyboard management from the menu.

### 2.6.0

- Use Settings → General to switch instantly between Simplified Chinese and English or enable launch at login. Settings → About shows the version and links to the project.
- Minimize the Settings, Rules, and Running Applications windows or close them with ⌘W. Fluor4me stays available in the menu bar.
- Requires an Apple silicon Mac with macOS 14 or later. Run `./scripts/build-app.py` with Python 3 and macOS Command Line Tools to build `dist/Fluor4me.app`.

Fluor4me is based on Pierre Tacchi’s [Fluor](https://github.com/Pyroh/Fluor) and draws on [fntoggle](https://github.com/nelsonjchen/fntoggle) for function-key switching. [MIT License](LICENSE)
