# 💼 AstrBot-Portable：你的随身 QQ 机器人

**无需网络下载，无需重复配置。插上 U 盘，即可在任何 Linux 设备上拥有一个能聊天的 QQ 机器人。**

---

## 📖 目录

1. [项目特性](#项目特性)
2. [两种部署模式](#两种部署模式)
3. [系统要求](#系统要求)
4. [准备工作：制作 U 盘](#准备工作制作-u-盘)
5. [Windows 端：生成离线包](#windows-端生成离线包)
6. [Linux 端：部署与运行](#linux-端部署与运行)
   - [便携模式](#便携模式)
   - [安装模式](#安装模式)
7. [常见问题](#常见问题)
8. [文件清单](#文件清单)
9. [致谢与许可](#致谢与许可)

---

## ✨ 项目特性

- 🤖 **全功能 QQ 机器人**：基于 [AstrBot](https://github.com/AstrBotDevs/AstrBot)，支持自动回复、接入大模型（DeepSeek/OpenAI）、多平台消息。
- 💾 **双模式部署**：可灵活切换“便携模式”（数据存 U 盘）和“安装模式”（数据存服务器硬盘）。
- 🌐 **离线可用**：Docker 镜像预先打包，无需互联网即可部署。
- 🖥️ **跨平台**：支持 Ubuntu、Debian、Arch、CentOS、树莓派、WSL2 等 Linux 环境。
- 🪟 **Windows 一键制备**：双击脚本自动拉取镜像并生成完整部署包。
- 🔌 **即插即用**：U 盘里自带所有脚本，插入任何 Linux 设备，一条命令启动。

---

## 🔄 两种部署模式

| 模式 | 数据存储位置 | 特点 | 适用场景 |
|------|------------|------|----------|
| **便携模式** (`start.sh`) | U 盘的 `ext4` 分区（若无则 fallback 到 exFAT） | 即插即用，拔掉 U 盘服务器无残留 | 临时演示、多台设备轮流使用、不想污染服务器 |
| **安装模式** (`install.sh`) | 服务器指定目录（如 `/opt/astrbot_data`） | 机器人永久运行，U 盘只做启动盘 | 长期提供服务，U 盘可拔掉 |

**同一个 U 盘，通过不同启动脚本实现两种模式。** 你可以根据需求随时切换。

---

## 📋 系统要求

### 在 Windows 上（用于制作离线包）
- **操作系统**：Windows 10/11 64位 专业版/企业版（家庭版不支持 WSL2 虚拟化）
- **CPU**：支持硬件虚拟化（Intel VT-x / AMD-V），并已在 BIOS 中开启
- **软件**：
  - [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)（安装时勾选“Use WSL 2 instead of Hyper-V”）
  - WSL 2 功能已启用（管理员 PowerShell 执行：`dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart` 和 `dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart`）
- **网络**：需要互联网以下载 Docker 镜像（仅首次制作时需要）
- **U 盘**：容量 ≥32GB，USB 3.0 推荐

### 在 Linux 设备上（用于部署运行）
- **操作系统**：任何主流 Linux 发行版（Ubuntu 20.04+、Debian 11+、Arch Linux、CentOS 7+、树莓派 OS、WSL2 等）
- **软件**：已安装 `docker` 和 `docker-compose`（或 `docker compose` 插件）
- **权限**：当前用户具有 sudo 权限（用于挂载 U 盘和运行 Docker）
- **硬件**：至少 2GB 内存，推荐 4GB+；CPU 无特殊要求

---

## 🛠️ 准备工作：制作 U 盘

本方案使用 [Ventoy](https://www.ventoy.net/) 制作启动 U 盘，并额外创建一个 ext4 分区用于便携模式数据存储。

### 步骤 1：安装 Ventoy 到 U 盘
1. 下载 Ventoy（Windows 版）并解压。
2. 插入 U 盘，以管理员身份运行 `Ventoy2Disk.exe`。
3. 在“设备”列表中**仔细选中你的 U 盘**（请勿选错），点击“安装”。
4. 等待完成。此时 U 盘会被分为两个区：一个大的 exFAT 数据区（存放 ISO 和脚本）和一个小的 VTOYEFI 引导区（**不要动它**）。

### 步骤 2：无损调整分区，创建 ext4 数据区
1. 下载并安装 [DiskGenius](https://www.diskgenius.cn/)（免费版即可）。
2. 打开 DiskGenius，在左侧磁盘列表中找到你的 U 盘（根据容量判断）。
3. 右键点击 U 盘的 **exFAT 分区**，选择“调整分区大小”。
4. 在弹出的窗口中，设置“分区后部的空闲空间”为 **20GB**（或你希望的大小），点击“开始”。
5. 操作完成后，你会看到一块“空闲”空间。右键点击它，选择“建立新分区”。
6. 文件系统类型选择 **EXT4**，大小保持默认，点击“确定”。
7. 最后点击顶部工具栏的“保存更改”，确认执行。

**结果**：你的 U 盘现在有三个分区：
- exFAT 分区（主数据区，放 ISO 和脚本）
- VTOYEFI 分区（引导区，不要动）
- ext4 分区（用于便携模式数据存储）

> **注意**：如果你不创建 ext4 分区，便携模式仍然可以工作（数据将存在 exFAT 分区），但 exFAT 在 Linux 下权限较弱，可能出现小问题。强烈建议创建 ext4 分区以获得最佳体验。

---

## 🪟 Windows 端：生成离线包

### 步骤 1：下载脚本
将 `AstrBot离线包生成器.ps1` 保存到你的电脑（例如桌面）。

### 步骤 2：运行脚本
- **右键**点击脚本文件，选择“使用 PowerShell 运行”。
- 脚本会自动：
  - 在桌面创建 `AstrBot_Offline` 文件夹
  - 拉取 AstrBot 的 Docker 镜像（使用 DaoCloud 加速源）
  - 将镜像保存为 `astrbot_latest.tar`
  - 生成所有部署脚本（`docker-compose.yml`, `mount.sh`, `start.sh`, `install.sh`, `stop.sh`）
- 等待约 5-10 分钟（取决于网络速度），看到“✅ 离线包生成完成！”即可。

### 步骤 3：复制到 U 盘
- 打开 U 盘的 **exFAT 分区**（即 Ventoy 数据区）。
- 将桌面上生成的 `AstrBot_Offline` 文件夹**整个复制**到该分区的根目录。

> **提示**：你可以同时将其他 Linux 发行版的 ISO 文件放在 exFAT 分区，Ventoy 会识别它们用于启动。

---

## 🐧 Linux 端：部署与运行

### 步骤 1：插入 U 盘并挂载
1. 将 U 盘插入 Linux 设备。
2. 打开终端，进入 U 盘挂载点。大多数桌面环境会自动挂载到 `/media/用户名/` 或 `/run/media/用户名/`。你也可以使用 `lsblk` 命令查看设备名并手动挂载。
3. 进入 `AstrBot_Offline` 目录：
   ```bash
   cd /path/to/AstrBot_Offline