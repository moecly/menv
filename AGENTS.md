# menv - 开发环境管理器

## 概述
`menv` 是一个 bash 脚本，用于管理 dotfile 仓库集合和系统配置脚本。运行于 Arch Linux，使用 `pacman`/`paru` 进行包管理。

## 关键路径
- **配置**: `config.conf` - 定义仓库、工具（包）和脚本
- **脚本**: `sh/*.sh` - 系统设置脚本（paru、swapfile、snapper、luks 等）
- **管理的仓库**: 克隆到 `${MOECLY_DIR:-$HOME/.moecly_conf}/<name>/`

## 命令
```bash
menv init        # 克隆所有 dotfile 仓库
menv pull        # 拉取所有仓库 + menv 自身
menv list        # 列出所有管理的仓库
menv link        # 在每个仓库中执行 link.sh（创建符号链接）
menv doctor      # 检查必需和可选工具是否已安装
menv install     # 安装缺失的包（pacman + AUR via paru）
menv install <category>  # 安装特定分类（base、shell、cli、wayland 等）
menv run <script> [args] # 运行 sh/ 中的脚本（paru、swapfile、snapper、luks 等）
menv run --list  # 列出可用脚本
menv protocol ssh|https  # 切换 git 远程协议
```

## 管理的仓库
每个仓库应包含一个 `link.sh` 脚本，用于创建指向 `$HOME` 的符号链接。

## 添加新工具
编辑 `config.conf` - 在 `TOOLS` 数组中添加条目：
```
"<source>:<category>:<type>:<package>:<commands>:<description>"
```
- source: pacman/aur/""（无包来源）
- category: base/shell/file/tui/pkg/wayland/input/cli/net/system/productivity
- type: required/optional
- package: 实际的 pacman/AUR 包名
- commands: 用于检测的空格分隔的命令
- description: 中文描述

## 添加新脚本
1. 在 `sh/<name>.sh` 创建脚本
2. 在 `config.conf` 的 `SCRIPTS` 数组中添加: `"<alias>:<filename>:<description>"`
