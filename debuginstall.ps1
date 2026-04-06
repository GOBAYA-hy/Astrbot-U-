# ================================================
# AstrBot 离线包生成器（Windows 版）
# 功能：自动创建目录、拉取镜像、打包、生成服务器脚本（支持双模式）
# 用法：右键“使用 PowerShell 运行”
# 修复优化：Docker环境检查、换行符兼容、错误容错、Linux依赖提示
# ================================================

# ========== 前置环境检查 ==========
# 检查Docker是否安装
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 错误：未检测到 Docker，请先安装 Docker Desktop 并启动" -ForegroundColor Red
    Write-Host "下载地址：https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    pause
    exit 1
}

# 检查Docker是否正常运行
if (-not (docker info 2> $null)) {
    Write-Host "❌ 错误：Docker 未启动，请先打开 Docker Desktop 并等待启动完成" -ForegroundColor Red
    pause
    exit 1
}

# ========== 1. 设置工作目录（桌面上的 AstrBot_Offline） ==========
$OFFLINE_DIR = "$env:USERPROFILE\Desktop\AstrBot_Offline"

# ========== 2. 创建目录（如果不存在则自动创建） ==========
if (!(Test-Path $OFFLINE_DIR)) {
    New-Item -ItemType Directory -Path $OFFLINE_DIR -Force | Out-Null
    Write-Host "✓ 已创建目录: $OFFLINE_DIR" -ForegroundColor Green
} else {
    Write-Host "✓ 目录已存在: $OFFLINE_DIR" -ForegroundColor Green
}

# ========== 3. 镜像地址（使用 DaoCloud 加速源，国内友好） ==========
$IMAGE_SOURCE = "m.daocloud.io/docker.io/soulter/astrbot:latest"
$TARGET_IMAGE = "soulter/astrbot:latest"

# ========== 4. 拉取镜像（加错误容错） ==========
Write-Host "正在拉取 AstrBot 镜像（约 2GB，请耐心等待）..." -ForegroundColor Cyan
docker pull $IMAGE_SOURCE
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 镜像拉取失败，请检查网络或更换镜像源" -ForegroundColor Red
    pause
    exit 1
}

# ========== 5. 重新标记为官方名 ==========
Write-Host "正在重新标记镜像..." -ForegroundColor Cyan
docker tag $IMAGE_SOURCE $TARGET_IMAGE
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 镜像标记失败" -ForegroundColor Red
    pause
    exit 1
}

# ========== 6. 保存为 tar 文件 ==========
$TAR_FILE = "$OFFLINE_DIR\astrbot_latest.tar"
Write-Host "正在保存镜像到: $TAR_FILE" -ForegroundColor Cyan
docker save -o $TAR_FILE $TARGET_IMAGE
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 镜像保存失败，请检查磁盘空间" -ForegroundColor Red
    pause
    exit 1
}
Write-Host "✓ 镜像保存完成" -ForegroundColor Green

# ========== 7. 生成 docker-compose.yml（模板，安装模式会修改挂载路径） ==========
$COMPOSE_CONTENT = @"
version: '3.8'

services:
  astrbot:
    image: soulter/astrbot:latest
    container_name: astrbot
    restart: unless-stopped
    ports:
      - "6185:6185"
      - "11451:11451"
    volumes:
      - ./data:/AstrBot/data
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=Asia/Shanghai
"@
$COMPOSE_PATH = "$OFFLINE_DIR\docker-compose.yml"
Set-Content -Path $COMPOSE_PATH -Value $COMPOSE_CONTENT -Encoding utf8
Write-Host "✓ 已生成 docker-compose.yml" -ForegroundColor Green

# ========== 通用：Linux脚本生成函数（统一处理LF换行符，避免Windows换行符兼容问题） ==========
function New-LinuxScript {
    param(
        [string]$Path,
        [string]$Content
    )
    # 替换CRLF为LF，UTF8无BOM编码，适配Linux
    $Content = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllLines($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

# ========== 8. 生成服务器端挂载脚本 mount.sh ==========
$MOUNT_SCRIPT = @'
#!/bin/bash
# 自动挂载脚本 - 自动创建挂载点并挂载U盘分区

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 前置检查：sudo权限
if ! sudo -v >/dev/null 2>&1; then
    echo -e "${RED}✗ 当前用户无sudo权限，请使用有sudo权限的用户执行${NC}"
    exit 1
fi

# 前置检查：lsblk命令
if ! command -v lsblk &> /dev/null; then
    echo -e "${RED}✗ 未找到lsblk命令，请先安装util-linux包${NC}"
    exit 1
fi

echo -e "${GREEN}========== 自动挂载 U 盘分区 ==========${NC}"

# 自动创建挂载点目录（无需手动创建）
sudo mkdir -p /mnt/ventoy_data
sudo mkdir -p /mnt/astrbot_data
echo -e "${GREEN}✓ 挂载点目录已创建${NC}"

# 查找 exFAT 分区（Ventoy 数据区）
EXFAT_PART=$(lsblk -o NAME,FSTYPE -l | grep -E "exfat|ntfs" | head -1 | awk '{print $1}')
if [ -z "$EXFAT_PART" ]; then
    echo -e "${RED}✗ 未找到 exFAT/NTFS 分区，请确认 U 盘已插入${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 找到 exFAT 分区: /dev/$EXFAT_PART${NC}"

# 查找 ext4 分区（可选）
EXT4_PART=$(lsblk -o NAME,FSTYPE -l | grep "ext4" | head -1 | awk '{print $1}')
if [ -n "$EXT4_PART" ]; then
    echo -e "${GREEN}✓ 找到 ext4 分区: /dev/$EXT4_PART，将用作数据分区${NC}"
else
    echo -e "${YELLOW}⚠ 未找到 ext4 分区，将仅使用 exFAT 分区存储数据${NC}"
fi

# 挂载 exFAT 分区
echo -e "${YELLOW}正在挂载 exFAT/NTFS 分区...${NC}"
sudo mount -t exfat /dev/$EXFAT_PART /mnt/ventoy_data 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ exFAT 分区已挂载到 /mnt/ventoy_data${NC}"
else
    echo -e "${RED}✗ exFAT 挂载失败，尝试 ntfs 格式...${NC}"
    sudo mount -t ntfs-3g /dev/$EXFAT_PART /mnt/ventoy_data 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ NTFS 分区已挂载到 /mnt/ventoy_data${NC}"
    else
        echo -e "${RED}✗ 挂载失败！请先安装依赖：${NC}"
        echo -e "${YELLOW}Debian/Ubuntu: sudo apt install exfat-utils exfat-fuse ntfs-3g -y${NC}"
        echo -e "${YELLOW}CentOS/RHEL: sudo yum install exfatprogs ntfs-3g -y${NC}"
        exit 1
    fi
fi

# 挂载 ext4 分区（如果存在）
if [ -n "$EXT4_PART" ]; then
    sudo mount -t ext4 /dev/$EXT4_PART /mnt/astrbot_data 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ext4 分区已挂载到 /mnt/astrbot_data${NC}"
    else
        echo -e "${YELLOW}⚠ ext4 挂载失败，将仅使用 exFAT 分区${NC}"
    fi
fi

echo -e "${GREEN}========== 挂载完成 ==========${NC}"
echo "exFAT 分区位置: /mnt/ventoy_data"
[ -n "$EXT4_PART" ] && echo "ext4 分区位置: /mnt/astrbot_data"
'@
$MOUNT_PATH = "$OFFLINE_DIR\mount.sh"
New-LinuxScript -Path $MOUNT_PATH -Content $MOUNT_SCRIPT
Write-Host "✓ 已生成 mount.sh" -ForegroundColor Green

# ========== 9. 生成便携模式启动脚本 start.sh（数据存 U 盘） ==========
$START_SCRIPT = @'
#!/bin/bash
# 便携模式 - 数据存储在 U 盘（优先使用 ext4 分区，否则 exFAT）

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 前置检查：Docker环境
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ 未检测到 Docker，请先安装 Docker 环境${NC}"
    exit 1
fi

# 兼容Docker Compose v1/v2
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}✗ 未检测到 Docker Compose，请先安装${NC}"
    exit 1
fi

echo -e "${GREEN}========== AstrBot 便携模式 ==========${NC}"

# 进入脚本所在目录（U盘上的项目目录）
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 进入脚本目录失败${NC}"
    exit 1
fi
cd "$SCRIPT_DIR"

# 加载镜像
echo -e "${YELLOW}[1/4] 加载 Docker 镜像...${NC}"
if [[ "$(docker images -q soulter/astrbot:latest 2> /dev/null)" == "" ]]; then
    docker load -i ./astrbot_latest.tar
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 镜像加载失败，请检查 astrbot_latest.tar 文件是否完整${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ 镜像加载完成${NC}"
else
    echo -e "${GREEN}✓ 镜像已存在，跳过加载${NC}"
fi

# 配置数据目录
echo -e "${YELLOW}[2/4] 配置数据目录...${NC}"
if [ -d "/mnt/astrbot_data" ]; then
    echo -e "${GREEN}✓ 使用独立 ext4 分区存储数据${NC}"
    rm -rf ./data
    ln -sf /mnt/astrbot_data ./data
else
    echo -e "${YELLOW}⚠ 未检测到 ext4 分区，数据将存储在 U 盘 exFAT 分区${NC}"
    mkdir -p ./data
fi

# 停止旧容器
echo -e "${YELLOW}[3/4] 停止旧容器...${NC}"
$COMPOSE_CMD down 2>/dev/null

# 启动新容器
echo -e "${YELLOW}[4/4] 启动 AstrBot 容器...${NC}"
$COMPOSE_CMD up -d

# 检查状态
sleep 3
if docker ps | grep -q astrbot; then
    echo -e "${GREEN}========== AstrBot 启动成功！==========${NC}"
    echo -e "WebUI 地址: ${YELLOW}http://<你的服务器IP>:6185${NC}"
    echo -e "默认用户名/密码: ${YELLOW}astrbot / astrbot${NC}"
else
    echo -e "${RED}✗ 启动失败，请执行: docker logs astrbot 查看错误日志${NC}"
    exit 1
fi
'@
$START_PATH = "$OFFLINE_DIR\start.sh"
New-LinuxScript -Path $START_PATH -Content $START_SCRIPT
Write-Host "✓ 已生成 start.sh (便携模式)" -ForegroundColor Green

# ========== 10. 生成安装模式脚本 install.sh（数据存服务器硬盘） ==========
$INSTALL_SCRIPT = @'
#!/bin/bash
# 安装模式 - 将 AstrBot 安装到服务器硬盘，U盘只做启动盘

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 前置检查：Docker环境
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ 未检测到 Docker，请先安装 Docker 环境${NC}"
    exit 1
fi

# 兼容Docker Compose v1/v2
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}✗ 未检测到 Docker Compose，请先安装${NC}"
    exit 1
fi

# 前置检查：sudo权限
if ! sudo -v >/dev/null 2>&1; then
    echo -e "${RED}✗ 当前用户无sudo权限，请使用有sudo权限的用户执行${NC}"
    exit 1
fi

echo -e "${GREEN}========== AstrBot 安装模式 ==========${NC}"

# 询问安装路径
read -p "请输入安装目录的绝对路径（例如 /opt/astrbot_data）: " DATA_PATH
if [ -z "$DATA_PATH" ]; then
    echo -e "${RED}路径不能为空，安装已取消${NC}"
    exit 1
fi

# 创建数据目录
sudo mkdir -p "$DATA_PATH"
sudo chown -R $USER:$USER "$DATA_PATH"
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 数据目录创建失败，请检查路径权限${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 数据目录已创建: $DATA_PATH${NC}"

# 进入脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 进入脚本目录失败${NC}"
    exit 1
fi
cd "$SCRIPT_DIR"

# 加载镜像
echo -e "${YELLOW}[1/4] 加载 Docker 镜像...${NC}"
if [[ "$(docker images -q soulter/astrbot:latest 2> /dev/null)" == "" ]]; then
    docker load -i ./astrbot_latest.tar
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 镜像加载失败，请检查 astrbot_latest.tar 文件是否完整${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ 镜像加载完成${NC}"
else
    echo -e "${GREEN}✓ 镜像已存在，跳过加载${NC}"
fi

# 修改 docker-compose.yml 中的数据卷挂载路径（备份原文件，修复sed路径分隔符bug）
echo -e "${YELLOW}[2/4] 配置数据目录映射...${NC}"
cp docker-compose.yml docker-compose.yml.bak
# 用|作为分隔符，避免路径中的/导致sed报错
sed -i "s|- ./data:/AstrBot/data|- $DATA_PATH:/AstrBot/data|g" docker-compose.yml
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 配置文件修改失败${NC}"
    mv docker-compose.yml.bak docker-compose.yml
    exit 1
fi

# 停止旧容器
echo -e "${YELLOW}[3/4] 停止旧容器...${NC}"
$COMPOSE_CMD down 2>/dev/null

# 启动新容器
echo -e "${YELLOW}[4/4] 启动 AstrBot 容器...${NC}"
$COMPOSE_CMD up -d

# 恢复原始 compose 文件
mv docker-compose.yml.bak docker-compose.yml

# 检查状态
sleep 3
if docker ps | grep -q astrbot; then
    echo -e "${GREEN}========== AstrBot 安装成功！==========${NC}"
    echo -e "数据目录: ${YELLOW}$DATA_PATH${NC}"
    echo -e "WebUI 地址: ${YELLOW}http://<你的IP>:6185${NC}"
    echo -e "默认用户名/密码: ${YELLOW}astrbot / astrbot${NC}"
    echo -e "${GREEN}安装完成后可拔出U盘，不影响服务运行${NC}"
else
    echo -e "${RED}✗ 安装失败，请执行: docker logs astrbot 查看错误日志${NC}"
    mv docker-compose.yml.bak docker-compose.yml
    exit 1
fi
'@
$INSTALL_PATH = "$OFFLINE_DIR\install.sh"
New-LinuxScript -Path $INSTALL_PATH -Content $INSTALL_SCRIPT
Write-Host "✓ 已生成 install.sh (安装模式)" -ForegroundColor Green

# ========== 11. 生成停止脚本 stop.sh ==========
$STOP_SCRIPT = @'
#!/bin/bash
# 停止AstrBot服务脚本

# 兼容Docker Compose v1/v2
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ 未检测到 Docker Compose"
    exit 1
fi

cd "$(dirname "$0")"
$COMPOSE_CMD down
echo "✅ AstrBot 已停止"
'@
$STOP_PATH = "$OFFLINE_DIR\stop.sh"
New-LinuxScript -Path $STOP_PATH -Content $STOP_SCRIPT
Write-Host "✓ 已生成 stop.sh" -ForegroundColor Green

# ========== 最终输出 ==========
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ 离线包生成完成！" -ForegroundColor Green
Write-Host "📁 位置: $OFFLINE_DIR"
Write-Host "📄 包含文件:"
Write-Host "   - astrbot_latest.tar (离线镜像)"
Write-Host "   - docker-compose.yml (容器配置)"
Write-Host "   - mount.sh (U盘自动挂载脚本)"
Write-Host "   - start.sh (便携模式启动)"
Write-Host "   - install.sh (安装模式部署)"
Write-Host "   - stop.sh (服务停止脚本)"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📌 下一步操作："
Write-Host "1. 将整个 AstrBot_Offline 文件夹复制到 U 盘的 exFAT 分区"
Write-Host "2. Linux 设备上先安装依赖：sudo apt install exfat-utils exfat-fuse ntfs-3g -y"
Write-Host "3. 进入U盘目录：cd /mnt/ventoy_data/AstrBot_Offline"
Write-Host "4. 赋予权限：chmod +x *.sh"
Write-Host "5. 执行挂载：./mount.sh"
Write-Host "6. 选择模式：./start.sh (便携) 或 ./install.sh (安装)"
Write-Host "========================================`n" -ForegroundColor Cyan
pause
