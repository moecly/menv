# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

`menv` 是一个基于 Bash 的开发环境管理工具，支持宿主包管理器和 distrobox 容器安装。用于管理 dotfiles 仓库、系统工具安装和系统配置脚本。

## 常用命令

```bash
./menv init        # 克隆所有 dotfiles 仓库到 ~/.moecly_conf
./menv pull        # 更新所有仓库（包括 menv 自身）
./menv list        # 列出所有仓库及状态
./menv link        # 执行各仓库中的 link.sh 脚本
./menv status      # 显示仓库和工具安装概览
./menv doctor      # 检查工具依赖是否满足
./menv install     # 安装缺失的工具
./menv install -i  # 交互式选择安装（fzf）
./menv install cli # 按分类安装
./menv box setup   # 创建所有配置的 distrobox 容器
./menv box list    # 列出 distrobox 容器
./menv box enter arch  # 进入容器
./menv box upgrade # 升级所有容器
./menv run --list  # 列出可用脚本
./menv run paru    # 运行指定脚本
./menv protocol ssh|https  # 切换 Git 克隆协议
```

## 架构

- `menv` - 主入口脚本，包含所有命令实现
- `sh/` - 独立功能脚本（paru.sh, swapfile.sh, snapper.sh 等）
- `config/` - 配置文件（都是 bash 变量声明）
  - `repos.conf` - dotfiles 仓库列表（克隆到 `$MOECLY_DIR`，默认 `~/.moecly_conf`）
  - `tools.conf` - 工具列表（统一 `target:pkg_mgr:export` 格式）
  - `scripts.conf` - 可运行脚本注册
  - `distrobox.conf` - distrobox 容器定义

### 配置格式

**TOOLS 格式**（tools.conf）:
```
target:pkg_mgr:export:category:type:package:commands:description
```
- target: `root`（宿主系统）或容器名（定义在 distrobox.conf）
- pkg_mgr: `pacman` / `aur` / `dnf` / `apt` / `snap` 等
- export: `cli`（导出二进制）/ `app`（导出桌面应用）/ `none`（仅容器内）
- category: 英文别名（见 CATEGORY_ALIASES）
- type: `required` / `optional`
- package: 实际的包名
- commands: 用于检测是否已安装的命令（空格分隔）

**DISTROBOX_CONTAINERS 格式**（distrobox.conf）:
```
name:image[:home_dir]
```
- home_dir: 可选，空则默认 `$MOECLY_DIR/distrobox/<name>`，指定则覆盖

**REPOS 格式**（repos.conf）:
```
name:clone_url
```

**SCRIPTS 格式**（scripts.conf）:
```
alias:filename:description
```

### 环境变量

- `MOECLY_DIR` - 覆盖默认的 `~/.moecly_conf` 路径
- `DISTROBOX_EXPORT_PATH` - distrobox 二进制导出路径（默认 `$MOECLY_DIR/distrobox_bin`）
