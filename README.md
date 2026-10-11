# Arch Linux Hyprland 一键配置脚本

[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff)](https://archlinux.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-0.56%2B-58E1FF)](https://hyprland.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

一个为 Arch Linux 打造的完整桌面环境配置脚本，基于 **Hyprland + Lua 配置**，集成终端、输入法、状态栏、文件管理器、风扇控制等一整套工具链，适合快速部署一台可用的 Wayland 桌面。

## ✨ 包含内容

| 类别 | 组件 | 说明 |
|---|---|---|
| 合成器 | **Hyprland** + uwsm | 使用 Lua 配置（`hyprland.lua`） |
| 终端 | **Kitty** | JetBrainsMono Nerd Font |
| 状态栏 | **Waybar**（AUR 的 `waybar-git`） | 修复 Hyprland 0.55+ 工作区点击问题 |
| 通知 | **dunst** | |
| 壁纸 | **hyprpaper** | |
| 输入法 | **Fcitx5** + 小鹤双拼 | 深色主题 |
| 文件管理器 | **Yazi**（终端） + **Dolphin**（图形） | Yazi 设为默认 `inode/directory` |
| 编辑器 | **Neovim** | 基础剪贴板配置 |
| 浏览器 | **Firefox** | |
| Shell | **zsh** | zsh-autosuggestions + zoxide + fzf |
| 音频 | **PipeWire** + **WirePlumber** + **pipewire-pulse** | 完整音频栈 |
| 电源 | **power-profiles-daemon** | Waybar 电源模块依赖 |
| 风扇 | **fan2go** + **nvidiactl** | 主板 PWM 控制 + NVIDIA 显卡风扇 |
| 启动器 | **hyprlauncher**（AUR） | |
| 字体 | Noto CJK / Nerd Fonts / Adobe Source Han | |

## 📋 前置要求

- **Arch Linux** 基础系统已安装（`base-devel`、能联网）
- 有 `sudo` 权限的普通用户
- 已安装 `git`
- 桌面环境是 **Hyprland 0.56 或更高版本**（Lua 配置需要）
- 如果使用 NVIDIA 显卡，已安装闭源驱动（`nvidia` / `nvidia-dkms`）

## 🚀 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/<yourname>/arch-hyprland-setup.git
cd arch-hyprland-setup

# 2. 赋予执行权限
chmod +x arch-setup.sh

# 3. 先试运行，看看会做什么（不改系统）
./arch-setup.sh --dry-run

# 4. 正式执行
./arch-setup.sh
