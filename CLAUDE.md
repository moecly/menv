# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

`menv` 是一个基于 Bash 的开发环境管理工具，专为 Arch Linux 设计。用于管理 dotfiles 仓库、系统工具安装和系统配置脚本。

## 常用命令

```bash
./menv init        # 克隆所有 dotfiles 仓库到 ~/.moecly_conf
./menv pull        # 更新所有仓库（包括 menv 自身）
./menv list        # 列出所有仓库及状态
./menv link        # 执行各仓库中的 link.sh 脚本
./menv status      # 显示仓库和工具安装概览
./menv doctor      # 检查工具依赖是否满足
./menv install     # 安装缺失的工具（pacman + AUR）
./menv install -i  # 交互式选择安装（fzf）
./menv install cli # 按分类安装
./menv run --list  # 列出可用脚本
./menv run paru    # 运行指定脚本
./menv protocol ssh|https  # 切换 Git 克隆协议
```

## 架构

- `menv` - 主入口脚本，包含所有命令实现
- `sh/` - 独立功能脚本（paru.sh, swapfile.sh, snapper.sh 等）
- `config/` - 配置文件（都是 bash 变量声明）
  - `repos.conf` - dotfiles 仓库列表（克隆到 `$MOECLY_DIR`，默认 `~/.moecly_conf`）
  - `tools.conf` - 工具列表（格式：`source:category:package:commands:description`）
  - `scripts.conf` - 可运行脚本注册

### 配置格式

**TOOLS 格式**（tools.conf）:
```
source:category:package:commands:description
```
- source: `pacman` / `aur` / 空（无包源）
- category: 英文别名（见 CATEGORY_ALIASES）
- package: 实际的包名
- commands: 用于检测是否已安装的命令（空格分隔）

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
