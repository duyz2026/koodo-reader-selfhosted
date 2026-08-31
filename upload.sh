#!/usr/bin/env bash
# koodo-sync-hub 上传脚本
# 用途：GitHub 建仓前，把本机（开发机）代码推送到服务器
# 用法：./upload.sh <服务器地址> [目标目录]
#   例：./upload.sh 100.86.58.36
#   例：./upload.sh ibm-t460-dyz /opt/koodo-sync-hub
set -euo pipefail

TARGET="${1:?用法: ./upload.sh <服务器地址> [目标目录]}"
DEST="${2:-/opt/koodo-sync-hub}"
SSH_USER="${SSH_USER:-root}"

FILES=(
  install.sh koodo-hub upload.sh
  docker-compose.yml docker-compose.http.yml docker-compose.tls.yml
  # 冻结契约：版本号 + 镜像 digest 锁，必须与代码同态
  VERSION koodo-image.lock
  .env.example .gitignore
  LICENSE NOTICE README.md CHANGELOG.md CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md
  docs reverse-proxy .github
)

echo "[upload] 上传代码到 ${SSH_USER}@${TARGET}:${DEST}"
ssh "${SSH_USER}@${TARGET}" "mkdir -p ${DEST}"
scp -r "${FILES[@]}" "${SSH_USER}@${TARGET}:${DEST}/"

echo "[upload] 完成。接下来："
echo "  ssh ${SSH_USER}@${TARGET}"
echo "  cd ${DEST} && sudo bash install.sh"
