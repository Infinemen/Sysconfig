#!/usr/bin/env bash
# ============================================================
# Arch Linux 完整环境配置脚本
# Hyprland + Kitty + Fcitx5 + Waybar(git) + Yazi + Neovim + zsh + uwsm
# + fan2go + nvidiactl（风扇控制）
#
# 用法:
#   ./arch-setup.sh                  # 交互式全量配置
#   ./arch-setup.sh --dry-run        # 只显示会做什么
#   ./arch-setup.sh --terminal kitty # 指定终端
#   ./arch-setup.sh --uninstall-yazi # 移除 Yazi 文件浏览器配置
#   ./arch-setup.sh --help
# ============================================================
set -euo pipefail

# ────────────────────────────────────────────────────────────
# 常量
# ────────────────────────────────────────────────────────────
SCRIPT_NAME="$(basename "$0")"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d-%H%M%S)"

HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
YAZI_DESKTOP="$HOME/.local/share/applications/yazi.desktop"
PORTALS_CONF="$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
TFC_CONF_DIR="$HOME/.config/xdg-desktop-portal-termfilechooser"

FAN2GO_CONF="/etc/fan2go/fan2go.yaml"
NVIDIA_CTL_CONF="/etc/nvidiactl.conf"

MARK_BEGIN="-- >>> yazi file manager >>>"
MARK_END="-- <<< yazi file manager <<<"

TERMINAL=""
DRY_RUN=0
UNINSTALL_YAZI=0

# ────────────────────────────────────────────────────────────
# 日志
# ────────────────────────────────────────────────────────────
if [[ -t 2 ]]; then
  c_reset=$'\033[0m'; c_info=$'\033[1;34m'; c_ok=$'\033[1;32m'
  c_warn=$'\033[1;33m'; c_err=$'\033[1;31m'
else
  c_reset=''; c_info=''; c_ok=''; c_warn=''; c_err=''
fi

info()  { printf '%s[INFO]%s %s\n'  "$c_info" "$c_reset" "$*" >&2; }
ok()    { printf '%s[ OK ]%s %s\n'  "$c_ok"   "$c_reset" "$*" >&2; }
warn()  { printf '%s[WARN]%s %s\n'  "$c_warn" "$c_reset" "$*" >&2; }
err()   { printf '%s[ERR ]%s %s\n'  "$c_err"  "$c_reset" "$*" >&2; }
die()   { err "$*"; exit 1; }
confirm() { read -rp "$1 [y/N] " ans; [[ "${ans,,}" == "y" ]]; }

trap 's=$?; err "failed at line $LINENO (exit $s)"; exit $s' ERR

# ────────────────────────────────────────────────────────────
# 工具
# ────────────────────────────────────────────────────────────
have()   { command -v "$1" >/dev/null 2>&1; }

backup() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  if (( DRY_RUN )); then
    info "would backup: $f -> ${f}${BACKUP_SUFFIX}"
    return 0
  fi
  cp -a "$f" "${f}${BACKUP_SUFFIX}"
  ok "backup: $f -> ${f}${BACKUP_SUFFIX}"
}

usage() {
  cat <<EOF
$SCRIPT_NAME — Arch Linux 完整环境配置脚本

选项:
  --dry-run, -n         只显示会做什么，不改系统
  --terminal, -t NAME   指定终端 (kitty|alacritty|foot|wezterm)
  --uninstall-yazi      移除 Yazi 文件浏览器相关配置
  -h, --help            显示帮助

示例:
  $SCRIPT_NAME
  $SCRIPT_NAME --terminal kitty
  $SCRIPT_NAME --dry-run
  $SCRIPT_NAME --uninstall-yazi
EOF
}

parse_args() {
  while (( $# )); do
    case "$1" in
      --dry-run|-n)      DRY_RUN=1; shift ;;
      --terminal|-t)     TERMINAL="${2:-}"; [[ -n "$TERMINAL" ]] || die "--terminal 需要参数"; shift 2 ;;
      --uninstall-yazi)  UNINSTALL_YAZI=1; shift ;;
      -h|--help)         usage; exit 0 ;;
      *)                 die "未知选项: $1 (用 --help)" ;;
    esac
  done
}

# ────────────────────────────────────────────────────────────
# 终端探测
# ────────────────────────────────────────────────────────────
detect_terminal() {
  if [[ -n "$TERMINAL" ]]; then
    have "$TERMINAL" || die "终端不存在: $TERMINAL"
    return
  fi
  local t
  for t in kitty alacritty foot wezterm; do
    if have "$t"; then TERMINAL="$t"; return; fi
  done
  TERMINAL="kitty"
  warn "未检测到受支持的终端，回退到 kitty"
}

term_full_cmd() {
  case "$TERMINAL" in
    kitty|alacritty) echo "$TERMINAL --class yazi -e yazi" ;;
    foot)            echo "$TERMINAL --app-id=yazi yazi" ;;
    wezterm)         echo "$TERMINAL start --class yazi -- yazi" ;;
    *)               echo "$TERMINAL --class yazi -e yazi" ;;
  esac
}

# ============================================================
# 1. 镜像源
# ============================================================
setup_mirror() {
    info "配置 pacman 国内镜像源..."
    sudo pacman -S --needed --noconfirm reflector
    sudo reflector --country China --latest 20 --protocol https \
        --sort rate --save /etc/pacman.d/mirrorlist
    sudo pacman -Syyu --noconfirm
}

# ============================================================
# 2. paru
# ============================================================
install_paru() {
    command -v paru &>/dev/null && { info "paru 已安装"; return; }
    info "安装 paru..."
    local tmp; tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

# ============================================================
# 3. 安装软件包
# ============================================================
install_packages() {
    info "安装官方仓库软件包..."
    sudo pacman -S --needed --noconfirm \
        base-devel git wget curl unzip reflector \
        zsh zsh-autosuggestions \
        hyprland uwsm hyprpaper dunst wl-clipboard \
        kitty neovim dolphin firefox \
        fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-gtk fcitx5-qt \
        noto-fonts noto-fonts-cjk noto-fonts-emoji \
        otf-font-awesome ttf-nerd-fonts-symbols \
        adobe-source-han-sans-cn-fonts \
        ttf-joypixels ttf-symbola \
        yazi ffmpegthumbnailer poppler imagemagick bat glow unarchiver \
        jq mediainfo fd ripgrep zoxide fzf \
        pamixer brightnessctl playerctl \
        mpv zathura \
        pipewire pipewire-pulse pipewire-alsa wireplumber \
        power-profiles-daemon \
        lm_sensors \
        xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    # ★ lm_sensors —— fan2go 依赖它读取温度和风扇传感器

    if pacman -Qq pipewire-media-session >/dev/null 2>&1; then
        warn "检测到 pipewire-media-session，与 wireplumber 冲突，正在移除..."
        sudo pacman -Rns --noconfirm pipewire-media-session || true
    fi

    if pacman -Qq waybar >/dev/null 2>&1; then
        warn "移除官方仓库 waybar，改用 waybar-git..."
        sudo pacman -Rns --noconfirm waybar || true
    fi

    info "安装 Nerd Font 字体..."
    sudo pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd \
        || paru -S --noconfirm ttf-jetbrains-mono-nerd \
        || warn "JetBrainsMono Nerd Font 安装失败，请手动安装"

    info "安装 AUR 包..."
    paru -S --noconfirm waybar-git 2>/dev/null \
        || warn "waybar-git 安装失败，请手动检查"
    paru -S --noconfirm hyprlauncher 2>/dev/null \
        || warn "hyprlauncher 安装失败，请手动检查"

    info "安装 fan2go..."
    paru -S --noconfirm fan2go-git 2>/dev/null \
        || warn "fan2go-git 安装失败，请手动检查"

    if have nvidia-smi; then
        info "检测到 NVIDIA GPU，安装 nvidiactl..."
        paru -S --noconfirm nvidiactl-git 2>/dev/null \
            || warn "nvidiactl-git 安装失败，请手动检查"
    else
        warn "未检测到 nvidia-smi，跳过 nvidiactl"
    fi

    if pacman -Qq xdg-desktop-portal-termfilechooser >/dev/null 2>&1; then
        warn "检测到 xdg-desktop-portal-termfilechooser，本方案已不再需要"
        confirm "是否卸载它？" && sudo pacman -Rns --noconfirm xdg-desktop-portal-termfilechooser || true
    fi
}

# ============================================================
# 3.5 音频服务
# ============================================================
setup_audio() {
    info "启用 PipeWire + WirePlumber 用户服务..."
    if (( DRY_RUN )); then
        info "would enable & restart pipewire / pipewire-pulse / wireplumber"
        return 0
    fi

    systemctl --user enable --now pipewire.socket 2>/dev/null || true
    systemctl --user enable --now pipewire-pulse.socket 2>/dev/null || true
    systemctl --user enable --now wireplumber.service 2>/dev/null || true

    systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null || true

    if command -v pactl >/dev/null 2>&1; then
        if pactl info >/dev/null 2>&1; then
            ok "PulseAudio 兼容层正常"
        else
            warn "pactl 无法连接，请重新登录后再试"
        fi
    fi
    if command -v wpctl >/dev/null 2>&1; then
        wpctl status >/dev/null 2>&1 && ok "WirePlumber 正常" \
            || warn "wpctl 无法连接，请重新登录后再试"
    fi
    ok "音频服务配置完成"
}

# ============================================================
# 3.6 input 用户组
# ============================================================
setup_input_group() {
    info "配置 input 用户组（Waybar keyboard-state 需要）..."
    if (( DRY_RUN )); then
        info "would add $USER to group 'input'"
        return 0
    fi
    if id -nG "$USER" | tr ' ' '\n' | grep -qx input; then
        ok "$USER 已在 input 组"
    else
        sudo usermod -aG input "$USER"
        ok "已将 $USER 加入 input 组（重新登录后生效）"
    fi
}

# ============================================================
# 3.7 电源配置守护进程
# ============================================================
setup_power_profiles() {
    info "启用 power-profiles-daemon..."
    if (( DRY_RUN )); then
        info "would enable --now power-profiles-daemon"
        return 0
    fi
    sudo systemctl enable --now power-profiles-daemon 2>/dev/null || true
    sudo systemctl restart power-profiles-daemon 2>/dev/null || true
    if systemctl is-active --quiet power-profiles-daemon; then
        ok "power-profiles-daemon 已启用"
    else
        warn "power-profiles-daemon 未运行，请检查是否有冲突（如 TLP）"
    fi
}

# ============================================================
# 4. Hyprland 配置
# ============================================================
setup_hyprland() {
    info "生成 Hyprland 配置..."
    mkdir -p "$HOME/.config/hypr"

    cat > "$HYPR_LUA" <<'HYPR_EOF'
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- HYPRLAND CONFIG                                        --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --


------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local menu        = "hyprlauncher"
local browser     = "firefox"


-------------------
---- AUTOSTART ----
-------------------

-- 启动必要的后台进程
hl.on("hyprland.start", function ()
    -- 启动通知守护进程
    hl.exec_cmd("dunst")
    -- 启动状态栏（如果你用 waybar）
    hl.exec_cmd("waybar")
    -- 启动壁纸工具（如果你用 hyprpaper）
    hl.exec_cmd("hyprpaper -c /home/men/.config/hypr/hyprpaper.conf")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")


-----------------------
----- PERMISSIONS -----
-----------------------

-- 需要时取消注释
-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 4,
        gaps_out = 8,

        border_size = 1,

        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 4,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = false,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- 动画曲线
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0},  {0.1, 1}  } })

hl.animation({ leaf = "global",        enabled = true, speed = 8,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5,   bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4,   bezier = "easeOutQuint", style = "popin 95%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 3,   bezier = "easeOutQuint", style = "popin 95%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 4,   bezier = "quick" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 3,   bezier = "quick" })
hl.animation({ leaf = "fade",          enabled = true, speed = 4,   bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 4,   bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,   bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 3,   bezier = "quick", style = "fade" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4,   bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 4,   bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 3,   bezier = "quick", style = "fade" })

-- 智能间隙（按需取消注释）
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- 示例：按设备名单独配置
-- hl.device({
--     name        = "epic-mouse-v1",
--     sensitivity = -0.5,
-- })


---------------------
---- KEYBINDINGS ----
---------------------

-- local mainMod = "SUPER"
local mainMod = "ALT"

-- 重启Hypr
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
-- 软件开关
hl.bind(mainMod .. " + C", hl.dsp.window.close())                       -- 关闭窗口
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))                   -- 终端
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("kitty --class yazi -e yazi"))  -- yazi
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))                    -- 浏览器
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))                       -- 启动器

-- 平铺设定
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))  -- 浮动
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())                      -- 伪平铺


-- 焦点移动（vim 风格 HJKL 方向）
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

local swapWinMod = "SUPER"
-- 按顺序交换（与视觉方向无关，纯按栈顺序）
hl.bind(swapWinMod .. " + J", hl.dsp.window.swap({ next = true }))  -- 与下一个窗口交换
hl.bind(swapWinMod .. " + K", hl.dsp.window.swap({ prev = true }))  -- 与上一个窗口交换

-- 循环切换窗口（栈顺序，与方向无关）
hl.bind(mainMod .. " + TAB",         hl.dsp.window.cycle_next())

-- 工作区切换
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- 特殊工作区（scratchpad）
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- 滚轮切换工作区
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- 鼠标拖动/缩放窗口
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- 多媒体键
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- 忽略所有应用的最大化请求
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- 修复 XWayland 拖拽问题
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Hyprland-run 窗口规则
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- Yazi 浮动文件管理器
hl.window_rule({
    name  = "yazi-float",
    match = { class = "^yazi$" },
    float  = true,
    center = true,
    size   = "800 500",
})

-- 工艺仿真 浮动窗口
hl.window_rule({
    name  = "SEMISIM-float",
    match = { class = "^python3$" },
    float  = true,
    center = false,
    size   = "1000 700",
    move   = "monitor_w-1000 50"
})


-- ────────────────────────────────────────────────────────
-- 可选：把上面 yazi-float 改成右上角（替换那一整段）
-- ────────────────────────────────────────────────────────
-- hl.window_rule({
--     name   = "yazi-float",
--     match  = { class = "^yazi$" },
--     float  = true,
--     center = false,
--     size   = "800 500",
--     move   = "monitor_w-820 50",
-- })
HYPR_EOF
    ok "Hyprland 配置完成"
}

# ============================================================
# 5. hyprpaper
# ============================================================
setup_hyprpaper() {
    info "生成 hyprpaper 配置..."
    local wallpaper="$HOME/Files/wallpaper/1.jpg"
    [[ -f "$wallpaper" ]] || warn "壁纸文件不存在: $wallpaper"

    cat > "$HOME/.config/hypr/hyprpaper.conf" <<EOF
wallpaper {
    monitor =
    path = $wallpaper
    fit_mode = cover
}
EOF
    ok "hyprpaper 配置完成"
}

# ============================================================
# 6. Kitty
# ============================================================
setup_kitty() {
    info "生成 Kitty 配置..."
    mkdir -p "$HOME/.config/kitty"
    cat > "$HOME/.config/kitty/kitty.conf" <<'EOF'
font_family      JetBrainsMonoNF-Light
font_size        12
disable_ligatures never
EOF
    ok "Kitty 配置完成"
}

# ============================================================
# 7. Waybar
# ============================================================
setup_waybar() {
    info "生成 Waybar 配置..."
    mkdir -p "$HOME/.config/waybar"

    cat > "$HOME/.config/waybar/config.jsonc" <<'EOF'
// -*- mode: jsonc -*-
{
    "height": 30,
    "spacing": 4,
    "modules-left": [
        "hyprland/workspaces",
        "hyprland/mode",
        "hyprland/scratchpad",
        "custom/media"
    ],
    "modules-center": ["hyprland/window"],
    "modules-right": [
        "mpd", "idle_inhibitor", "pulseaudio", "network",
        "power-profiles-daemon", "cpu", "memory", "temperature",
        "backlight", "keyboard-state", "hyprland/language",
        "battery", "battery#bat2", "clock", "tray", "custom/power"
    ],

    // ★ 关键：让点击左上角工作区数字切换桌面
    //    配合 waybar-git 使用，修 Hyprland 0.55+ IPC 兼容问题
    "hyprland/workspaces": {
        "format": "{id}",
        "on-click": "activate",
        "on-scroll-up": "hyprctl dispatch workspace e+1",
        "on-scroll-down": "hyprctl dispatch workspace e-1",
        "all-outputs": true
    },

    "keyboard-state": {
        "numlock": true, "capslock": true,
        "format": "{name} {icon}",
        "format-icons": { "locked": "󰌾", "unlocked": "󰌿" }
    },
    "hyprland/mode": { "format": "<span style=\"italic\">{}</span>" },
    "hyprland/scratchpad": {
        "format": "{icon} {count}",
        "show-empty": false,
        "format-icons": ["", "󰖯"],
        "tooltip": true,
        "tooltip-format": "{app}: {title}"
    },
    "idle_inhibitor": {
        "format": "{icon}",
        "format-icons": { "activated": "󰅶", "deactivated": "󰾪" }
    },
    "tray": { "spacing": 10 },
    "clock": {
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "format-alt": "{:%Y-%m-%d}"
    },
    "cpu": { "format": "{usage}% 󰻠", "tooltip": false },
    "memory": { "format": "{}% 󰍛" },
    "temperature": {
        "critical-threshold": 80,
        "format": "{temperatureC}°C {icon}",
        "format-icons": ["󰜗", "󰔏", "󰸁"]
    },
    "backlight": {
        "format": "{percent}% {icon}",
        "format-icons": ["󰃞","󰃟","󰃠","󰃡","󰃢","󰃣","󰃤","󰃥","󰃦"]
    },
    "battery": {
        "states": { "warning": 30, "critical": 15 },
        "format": "{capacity}% {icon}",
        "format-full": "{capacity}% {icon}",
        "format-charging": "{capacity}% 󰂄",
        "format-plugged": "{capacity}% 󰂄",
        "format-alt": "{time} {icon}",
        "format-icons": ["󰁺","󰁻","󰁼","󰁽","󰁾"]
    },
    "battery#bat2": { "bat": "BAT2" },
    "power-profiles-daemon": {
        "format": "{icon}",
        "tooltip-format": "Power profile: {profile}\nDriver: {driver}",
        "tooltip": true,
        "format-icons": {
            "default": "󰒓", "performance": "󰒓",
            "balanced": "󰾅", "power-saver": "󰌪"
        }
    },
    "network": {
        "format-wifi": "{essid} ({signalStrength}%) 󰖩",
        "format-ethernet": "{ipaddr}/{cidr} 󰈀",
        "tooltip-format": "{ifname} via {gwaddr} 󰈀",
        "format-linked": "{ifname} (No IP) 󰈀",
        "format-disconnected": "Disconnected ⚠",
        "format-alt": "{ifname}: {ipaddr}/{cidr}"
    },
    "pulseaudio": {
        "scroll-step": 5,
        "format": "{volume}% {icon} {format_source}",
        "format-bluetooth": "{volume}% {icon}󰂯 {format_source}",
        "format-bluetooth-muted": "󰝟 {icon}󰂯 {format_source}",
        "format-muted": "󰝟 {format_source}",
        "format-source": "{volume}% 󰍬",
        "format-source-muted": "󰍭",
        "format-icons": {
            "headphone": "󰋋", "hands-free": "󰋎", "headset": "󰋎",
            "phone": "󰄜", "portable": "󰄜", "car": "󰄋",
            "default": ["󰕿", "󰖀", "󰕾"]
        },
        "on-click": "pamixer -t",
        "on-scroll-up": "pamixer -i 5",
        "on-scroll-down": "pamixer -d 5"
    },
    "custom/media": {
        "format": "{icon} {text}",
        "return-type": "json",
        "max-length": 40,
        "format-icons": { "spotify": "󰓇", "default": "🎜" },
        "escape": true,
        "exec": "$HOME/.config/waybar/mediaplayer.py 2> /dev/null"
    },
    "custom/power": {
        "format": "⏻ ",
        "tooltip": false,
        "menu": "on-click",
        "menu-file": "$HOME/.config/waybar/power_menu.xml",
        "menu-actions": {
            "shutdown": "shutdown", "reboot": "reboot",
            "suspend": "systemctl suspend", "hibernate": "systemctl hibernate"
        }
    }
}
EOF

    cat > "$HOME/.config/waybar/style.css" <<'EOF'
* {
    font-family: "JetBrainsMono Nerd Font", "FontAwesome 6 Free", sans-serif;
    font-size: 13px;
    border: none;
    border-radius: 0;
    min-height: 0;
}

window#waybar {
    background-color: rgba(30, 30, 46, 0.95);
    color: #cdd6f4;
    border-bottom: 1px solid rgba(137, 180, 250, 0.3);
}

window#waybar.hidden { opacity: 0.2; }

button {
    box-shadow: inset 0 -3px transparent;
    border: none;
    border-radius: 0;
}

#workspaces button {
    padding: 0 8px;
    background-color: transparent;
    color: #6c7086;
}

#workspaces button.active {
    color: #89b4fa;
    background-color: transparent;
    box-shadow: inset 0 -2px #89b4fa;
}

#workspaces button.urgent { color: #f38ba8; }
#workspaces button:hover  { background-color: rgba(137, 180, 250, 0.15); }

#clock,
#battery,
#cpu,
#memory,
#temperature,
#backlight,
#network,
#pulseaudio,
#tray,
#idle_inhibitor,
#power-profiles-daemon,
#mpd,
#custom-media,
#keyboard-state,
#language {
    padding: 0 10px;
    background-color: transparent;
    color: #cdd6f4;
}

#cpu { color: #a6e3a1; }
#memory { color: #cba6f7; }
#temperature { color: #fab387; }
#temperature.critical { color: #f38ba8; }
#backlight { color: #f9e2af; }
#network { color: #89dceb; }
#network.disconnected { color: #f38ba8; }
#pulseaudio { color: #f9e2af; }
#pulseaudio.muted { color: #6c7086; }
#battery { color: #a6e3a1; }
#battery.warning { color: #f9e2af; }
#battery.critical { color: #f38ba8; }
#clock { color: #89b4fa; }
#language { color: #94e2d5; }
#keyboard-state { color: #a6e3a1; }
#idle_inhibitor.activated { color: #f9e2af; }
EOF
    ok "Waybar 配置完成（含工作区点击切换）"
}

# ============================================================
# 8. Yazi (核心配置)
# ============================================================
setup_yazi() {
    info "生成 Yazi 配置..."
    mkdir -p "$HOME/.config/yazi"

    cat > "$HOME/.config/yazi/yazi.toml" <<'EOF'
[manager]
ratio = [1, 4, 3]
sort_by = "natural"
sort_sensitive = false
sort_reverse = false
sort_dir_first = true
linemode = "size"
show_hidden = false
show_symlink = true
scrolloff = 5
mouse_events = ["click", "scroll"]

[preview]
max_width = 600
max_height = 600
cache_dir = "/tmp/yazi"
image_filter = "lanczos3"
image_quality = 90
tab_size = 2
syntax_theme = "base16-ocean.dark"

[opener]
edit    = [{ run = 'nvim "$@"',                desc = "Edit",    block = true }]
open    = [{ run = 'xdg-open "$@"',            desc = "Open",    orphan = true }]
reveal  = [{ run = 'dolphin --select "$@"',    desc = "Reveal",  orphan = true }]
extract = [{ run = 'unar "$@"',                desc = "Extract", orphan = true }]
play    = [{ run = 'mpv "$@"',                 desc = "Play",    orphan = true }]
view    = [{ run = 'zathura "$@"',             desc = "View",    orphan = true }]

[open]
rules = [
  { url = "*.md",     use = "edit" },
  { url = "*.pdf",    use = "view" },
  { url = "*.mp4",    use = "play" },
  { url = "*.mkv",    use = "play" },
  { url = "*.webm",   use = "play" },
  { url = "*.zip",    use = "extract" },
  { url = "*.rar",    use = "extract" },
  { url = "*.7z",     use = "extract" },
  { url = "*.tar.gz", use = "extract" },
  { url = "*.tar.xz", use = "extract" },
  { url = "*.tar.bz2",use = "extract" },
  { url = "*.tar.zst",use = "extract" },
]

[tasks]
micro_workers = 5
macro_workers = 10
bizarre_retry = 3
image_alloc = 536870912
image_bound = [0, 0]

[log]
enabled = false
level = "info"
EOF

    cat > "$HOME/.config/yazi/keymap.toml" <<'EOF'
[manager]
keymap = [
  { on = "j", run = "arrow_down" },
  { on = "k", run = "arrow_up" },
  { on = "h", run = "arrow_left" },
  { on = "l", run = "arrow_right" },
  { on = "y", run = "copy" },
  { on = "x", run = "cut" },
  { on = "p", run = "paste" },
  { on = "d", run = "delete" },
  { on = "a", run = "create" },
  { on = "r", run = "rename" },
  { on = "o", run = "open" },
  { on = "t", run = "toggle_preview" },
  { on = "q", run = "quit" },
]
EOF
    ok "Yazi 核心配置完成"
}

# ============================================================
# 9. Yazi 作为默认文件浏览器
# ============================================================
install_yazi_filebrowser() {
    info "配置 Yazi 为默认文件浏览器..."

    detect_terminal
    info "使用终端: $TERMINAL"

    local cmd; cmd="$(term_full_cmd)"

    local desktop_content
    desktop_content=$(cat <<EOF
[Desktop Entry]
Type=Application
Name=Yazi
Comment=Terminal file manager
Exec=${cmd} %u
Terminal=false
MimeType=inode/directory;
Categories=System;FileManager;
Icon=folder
EOF
)

    if (( DRY_RUN )); then
        info "would write: $YAZI_DESKTOP"
    else
        mkdir -p "$(dirname "$YAZI_DESKTOP")"
        backup "$YAZI_DESKTOP"
        printf '%s\n' "$desktop_content" > "$YAZI_DESKTOP"
        ok "write: $YAZI_DESKTOP"
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
        xdg-mime default yazi.desktop inode/directory
        ok "inode/directory -> yazi.desktop"
    fi

    local portals_content
    portals_content=$(cat <<'EOF'
[preferred]
default=hyprland;gtk
EOF
)
    if (( DRY_RUN )); then
        info "would write: $PORTALS_CONF"
    else
        mkdir -p "$(dirname "$PORTALS_CONF")"
        backup "$PORTALS_CONF"
        printf '%s\n' "$portals_content" > "$PORTALS_CONF"
        ok "write: $PORTALS_CONF"
    fi

    if [[ -d "$TFC_CONF_DIR" ]]; then
        if (( DRY_RUN )); then
            info "would remove: $TFC_CONF_DIR"
        else
            rm -rf "$TFC_CONF_DIR"
            ok "removed: $TFC_CONF_DIR (旧 termfilechooser 配置)"
        fi
    fi

    if (( DRY_RUN )); then
        info "would restart xdg-desktop-portal 相关服务"
    else
        systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
        systemctl --user restart xdg-desktop-portal-hyprland.service 2>/dev/null || true
        ok "portal 服务已重启"
    fi
}

uninstall_yazi_filebrowser() {
    info "移除 Yazi 文件浏览器配置..."

    local f
    for f in "$YAZI_DESKTOP" "$PORTALS_CONF"; do
        if [[ -e "$f" ]]; then
            if (( DRY_RUN )); then
                info "would remove: $f"
            else
                backup "$f"
                rm -f "$f"
                ok "removed: $f"
            fi
        fi
    done

    if [[ -f "$HYPR_LUA" ]] && grep -qF "$MARK_BEGIN" "$HYPR_LUA"; then
        if (( DRY_RUN )); then
            info "would remove yazi block from: $HYPR_LUA"
        else
            backup "$HYPR_LUA"
            awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
              index($0, b) { skip=1; next }
              index($0, e) { skip=0; next }
              !skip { print }
            ' "$HYPR_LUA" > "$HYPR_LUA.tmp"
            mv "$HYPR_LUA.tmp" "$HYPR_LUA"
            ok "removed yazi block from: $HYPR_LUA"
        fi
    fi

    if (( ! DRY_RUN )); then
        systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true
        systemctl --user restart xdg-desktop-portal-hyprland.service 2>/dev/null || true
    fi

    ok "卸载完成"
    info "重登后运行: xdg-mime default <你的文件管理器>.desktop inode/directory"
}

# ============================================================
# 10. Fcitx5
# ============================================================
setup_fcitx5() {
    info "生成 Fcitx5 配置..."
    mkdir -p "$HOME/.config/fcitx5/conf"

    cat > "$HOME/.config/fcitx5/conf/classicui.conf" <<'EOF'
Font="Source Han Sans CN 12"
MenuFont="Source Han Sans CN 10"
TrayFont="JetBrainsMono Nerd Font Mono Thin 10"
DarkTheme=Material-Color-Indigo
UseDarkTheme=True
UseAccentColor=False
EOF

    cat > "$HOME/.config/fcitx5/conf/pinyin.conf" <<'EOF'
# Shuangpin Profile
ShuangpinProfile=Xiaohe
CloudPinyinEnabled=True
CloudPinyinIndex=3
FirstRun=False
EOF
    ok "Fcitx5 配置完成 (小鹤双拼)"
}

# ============================================================
# 11. Neovim
# ============================================================
setup_neovim() {
    info "生成 Neovim 配置..."
    mkdir -p "$HOME/.config/nvim"
    cat > "$HOME/.config/nvim/init.lua" <<'EOF'
vim.opt.clipboard="unnamedplus"
EOF
    mkdir -p "$HOME/.local/bin"
    ln -sf /usr/bin/nvim "$HOME/.local/bin/vim"
    ok "Neovim 配置完成 (vim -> nvim)"
}

# ============================================================
# 12. zsh
# ============================================================
setup_zsh() {
    info "生成 zsh 配置..."
    cat > "$HOME/.zshrc" <<'EOF'
# ============================================================
#  ~/.zshrc  —  zsh 基础配置
#  修改后执行 `source ~/.zshrc` 生效
# ============================================================

# ------------------------------------------------------------
# 1. 环境变量
# ------------------------------------------------------------
export LANG="${LANG:-en_US.UTF-8}"
export EDITOR="${EDITOR:-vim}"
export PAGER="${PAGER:-less}"
export LESS="-R -F -X"

# ------------------------------------------------------------
# 2. 历史记录
# ------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt SHARE_HISTORY

# ------------------------------------------------------------
# 3. 通用选项
# ------------------------------------------------------------
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP
setopt PROMPT_SUBST

# ------------------------------------------------------------
# 4. 补全系统
# ------------------------------------------------------------
autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompcache"

# ------------------------------------------------------------
# 5. 键位绑定
# ------------------------------------------------------------
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# ------------------------------------------------------------
# 6. 命令别名
# ------------------------------------------------------------
if ls --color=auto >/dev/null 2>&1; then
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
else
  alias ls='ls -G'
fi

alias ll='ls -lh'
alias la='ls -lAh'
alias l='ls -CF'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias df='df -h'
alias du='du -h'
alias free='free -h'
alias mkdir='mkdir -pv'

alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'

# ------------------------------------------------------------
# 7. 提示符（含 git 分支，只显示当前目录）
# ------------------------------------------------------------
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats ' (%b)'
zstyle ':vcs_info:git:*' actionformats ' (%b|%a)'

precmd() { vcs_info }

PROMPT='%F{green}%n@%m%f:%F{blue}%1~%f%F{yellow}${vcs_info_msg_0_}%f%# '
RPROMPT='%(?..%F{red}[%?]%f)'

# ------------------------------------------------------------
# 8. 实用小函数
# ------------------------------------------------------------
mkcd() { mkdir -p "$1" && cd "$1"; }

extract() {
  case "$1" in
    *.tar.gz|*.tgz) tar xzf "$1" ;;
    *.tar.bz2)     tar xjf "$1" ;;
    *.tar.xz)      tar xJf "$1" ;;
    *.zip)         unzip "$1"   ;;
    *.gz)          gunzip "$1"  ;;
    *) echo "不支持的格式: $1" ;;
  esac
}

# ------------------------------------------------------------
# 9. zoxide（智能 cd）
# ------------------------------------------------------------
eval "$(zoxide init zsh)"

# ------------------------------------------------------------
# 10. fzf（模糊查找）
# ------------------------------------------------------------
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ]    && source /usr/share/fzf/completion.zsh

# ------------------------------------------------------------
# 11. zsh-autosuggestions（自动建议）
# ------------------------------------------------------------
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# ============================================================
# 结束
# ============================================================
EOF

    cat > "$HOME/.zprofile" <<'EOF'
if uwsm check may-start; then
    exec uwsm start hyprland.desktop
fi
EOF
    ok "zsh 配置完成 (含自动建议 + zoxide + fzf)"
}

# ============================================================
# 13. 字体缓存
# ============================================================
setup_font() {
    info "刷新字体缓存..."
    fc-cache -fv
}

# ============================================================
# 14. 风扇控制（fan2go + nvidiactl，极简 linear 版）
# ============================================================
setup_fan_control() {
    info "配置风扇控制（fan2go + nvidiactl）..."

    if (( DRY_RUN )); then
        info "would write: $FAN2GO_CONF"
        info "would write: $NVIDIA_CTL_CONF"
        info "would fix /etc/fan2go permission and remove stale db"
        info "would enable fan2go.service and nvidiactl.service"
        return 0
    fi

    # ── 先清理 /etc/fan2go 权限和旧的 db 文件 ──
    if [[ -d /etc/fan2go ]]; then
        sudo systemctl stop fan2go 2>/dev/null || true
        sudo rm -f /etc/fan2go/fan2go.db \
                   /etc/fan2go/fan2go.db-shm \
                   /etc/fan2go/fan2go.db-wal
    else
        sudo mkdir -p /etc/fan2go
    fi
    sudo chown -R root:root /etc/fan2go
    sudo chmod 755 /etc/fan2go

    # ── fan2go 配置（极简 linear）──
    if [[ -f "$FAN2GO_CONF" ]]; then
        sudo cp -a "$FAN2GO_CONF" "${FAN2GO_CONF}${BACKUP_SUFFIX}"
        ok "backup: $FAN2GO_CONF"
    fi

    sudo tee "$FAN2GO_CONF" >/dev/null <<'FAN2GO_EOF'
# /etc/fan2go/fan2go.yaml
# 华硕 nct6799 + AMD CPU + RTX 5090
# 极简 linear 版

dbPath: /etc/fan2go/fan2go.db

fans:
    # CPU 风扇（假设接在 fan1，如实际不同改 rpmChannel）
    - id: cpu_fan
      hwmon:
          platform: nct6799-isa-0290
          rpmChannel: 1
      curve: cpu_curve

    # 机箱风扇（假设接在 fan2，如实际不同改 rpmChannel）
    - id: case_fan
      hwmon:
          platform: nct6799-isa-0290
          rpmChannel: 2
      curve: case_curve

sensors:
    - id: cpu_temp
      hwmon:
          platform: k10temp-pci-00c3
          index: 1
      type: temperature

    - id: gpu_temp
      nvidia:
          device: nvidia-10DE2B85-0100
          index: 1

curves:
    # CPU 温度 -> 转速（平缓曲线）
    - id: cpu_curve
      linear:
          sensor: cpu_temp
          steps:
              - 40: 25
              - 60: 40
              - 75: 65
              - 85: 100

    # 机箱风扇跟着 GPU 温度走
    - id: case_curve
      linear:
          sensor: gpu_temp
          steps:
              - 50: 25
              - 70: 50
              - 85: 80
FAN2GO_EOF
    ok "write: $FAN2GO_CONF"

    # ── nvidiactl 配置（仅 NVIDIA 卡）──
    if have nvidia-smi; then
        if [[ -f "$NVIDIA_CTL_CONF" ]]; then
            sudo cp -a "$NVIDIA_CTL_CONF" "${NVIDIA_CTL_CONF}${BACKUP_SUFFIX}"
            ok "backup: $NVIDIA_CTL_CONF"
        fi

        sudo tee "$NVIDIA_CTL_CONF" >/dev/null <<'NVCTL_EOF'
# /etc/nvidiactl.conf
# NVIDIA 显卡风扇控制
# 具体键名以实际 nvidiactl 版本为准，见 `man nvidiactl` 或项目 README

temperature = 70
fanspeed = 85
hysteresis = 5
minspeed = 20
load_driven = true
NVCTL_EOF
        ok "write: $NVIDIA_CTL_CONF"
    else
        warn "未检测到 nvidia-smi，跳过 nvidiactl 配置"
    fi

    # ── 打印 fan2go detect，方便核对 platform 和通道号 ──
    if have fan2go; then
        echo
        info "==================================================="
        info "请核对下面 fan2go detect 的输出："
        info "  - platform 是否为 nct6799-isa-0290"
        info "  - cpu_fan / case_fan 的 rpmChannel 是否与风扇对应"
        info "  - NVIDIA 设备名是否为 nvidia-10DE2B85-0100"
        info "如不一致，编辑 $FAN2GO_CONF 后运行："
        info "  sudo fan2go config validate && sudo systemctl restart fan2go"
        info "==================================================="
        echo
        sudo fan2go detect 2>&1 || warn "fan2go detect 失败，请手动运行检查"
        echo
    fi

    # ── 启用服务 ──
    if have fan2go; then
        if sudo fan2go config validate >/dev/null 2>&1; then
            sudo systemctl enable --now fan2go.service 2>/dev/null \
                && ok "fan2go.service 已启用" \
                || warn "fan2go.service 启动失败，请检查日志"
        else
            warn "fan2go 配置未通过校验，暂不启动服务（检查 YAML 缩进和 platform 名）"
        fi
    fi

    if have nvidiactl; then
        sudo systemctl enable --now nvidiactl.service 2>/dev/null \
            && ok "nvidiactl.service 已启用" \
            || warn "nvidiactl.service 启动失败，请检查配置"
    fi

    ok "风扇控制配置完成"
}

# ============================================================
# 主流程
# ============================================================
main() {
    parse_args "$@"

    if (( UNINSTALL_YAZI )); then
        uninstall_yazi_filebrowser
        exit 0
    fi

    info "=== Arch Linux 完整环境配置脚本 ==="
    echo

    confirm "是否开始配置？" || { info "已取消"; exit 0; }

    confirm "配置国内镜像源？"          && setup_mirror
    confirm "安装 paru？"               && install_paru
    confirm "安装软件包？"              && install_packages
    confirm "启用音频服务（PipeWire/WirePlumber）？" && setup_audio
    confirm "将用户加入 input 组（修 keyboard-state 权限）？" && setup_input_group
    confirm "启用 power-profiles-daemon？" && setup_power_profiles
    confirm "生成 Hyprland 配置？"       && setup_hyprland
    confirm "生成 hyprpaper 配置？"      && setup_hyprpaper
    confirm "生成 Kitty 配置？"          && setup_kitty
    confirm "生成 Waybar 配置？"         && setup_waybar
    confirm "生成 Yazi 核心配置？"       && setup_yazi
    confirm "配置 Yazi 为默认文件浏览器？" && install_yazi_filebrowser
    confirm "生成 Fcitx5 配置？"         && setup_fcitx5
    confirm "生成 Neovim 配置？"         && setup_neovim
    confirm "生成 zsh 配置？"            && setup_zsh
    confirm "配置风扇控制（fan2go + nvidiactl）？" && setup_fan_control
    setup_font

    echo
    ok "=== 配置完成 ==="
    echo
    info "下一步："
    cat <<'EOF'
  1. 注销并重新登录，使以下变更生效：
       - Hyprland 和 portal
       - input 用户组（Waybar keyboard-state 权限）
       - PipeWire / WirePlumber 用户服务
  2. 首次登录后运行 fcitx5-configtool，确认小鹤双拼已启用
  3. 手动将 Waybar 的 power_menu.xml 和 mediaplayer.py 放入 ~/.config/waybar/
  4. Firefox 下载管理器「打开所在文件夹」走 yazi，需要改 about:config：
       widget.use-xdg-desktop-portal.open-uri = false
  5. 风扇控制：
       - 进 BIOS 把 CPU_FAN / CHA_FAN 改成 PWM 模式 + Q-Fan Manual
       - 核对 /etc/fan2go/fan2go.yaml 里的 platform 和 rpmChannel
       - 查看实时状态: journalctl -u fan2go -f
  6. 如果 hyprlauncher 启动时报 EGL 错误：
       - 试试临时命令：
         __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json hyprlauncher
       - 如果有效，把 hl.bind(mainMod .. " + R", ...) 改成带环境变量的版本：
         hl.bind(mainMod .. " + R",
             hl.dsp.exec_cmd("__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json hyprlauncher"))

快捷键速查：
  Alt + T / E / B / R     终端 / yazi / 浏览器 / 启动器
  Alt + HJKL              焦点移动
  Super + J / K           与上/下一个窗口交换位置
  Alt + Tab               循环切换窗口
  Alt + V / P             浮动 / 伪平铺
  Alt + 1..0              切换工作区
  Alt + Shift + 1..0      移动窗口到工作区
  Alt + S / Shift+S       特殊工作区
  Alt + 鼠标左键拖动      移动窗口
  Alt + 鼠标右键拖动      调整窗口大小

测试：
  sensors             -> 查看 CPU/GPU 温度
  sudo fan2go detect  -> 查看风扇和传感器
EOF
}

main "$@"