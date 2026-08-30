#!/usr/bin/env bash
# koodo-sync-hub 安装向导 v0.1.1
# 支持自定义 HTTP/HTTPS 端口，避免与已有 openresty/nginx 冲突
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

if [ -t 1 ]; then
  C='\033[36m'; G='\033[32m'; R='\033[31m'; Y='\033[33m'; N='\033[0m'
else C=''; G=''; R=''; Y=''; N=''; fi
info(){ echo -e "${C}[koodo-hub]${N} $*"; }
ok(){ echo -e "${G}[ok]${N} $*"; }
warn(){ echo -e "${Y}[warn]${N} $*"; }
err(){ echo -e "${R}[err]${N} $*" >&2; }

need(){ command -v "$1" >/dev/null 2>&1 || { err "缺少命令: $1"; exit 1; }; }

[ "$(id -u)" = "0" ] || { err "请使用 root 运行（sudo bash install.sh）"; exit 1; }
need docker
docker compose version >/dev/null 2>&1 || { err "需要 docker compose v2"; exit 1; }
docker info >/dev/null 2>&1 || { err "docker 守护进程未运行"; exit 1; }
[ -f .env ] && { err ".env 已存在，若需重装请先删除 .env 与数据目录"; exit 1; }

info "koodo-sync-hub 安装向导"

read -r -p "访问地址（公网 IP / 域名 / Tailscale 机器名）: " HOST
HOST="${HOST:-}"
[ -n "$HOST" ] || { err "地址不能为空"; exit 1; }

read -r -p "TLS 模式 [1=域名+Let's Encrypt / 2=自签证书(IP) / 3=纯HTTP(内网)] 默认2: " TLS
TLS="${TLS:-2}"
case "$TLS" in 1|2|3) ;; *) err "无效的 TLS 模式"; exit 1 ;; esac

read -r -p "HTTP 端口（默认 80；被占用请填 8090 等）: " HTTP_PORT
HTTP_PORT="${HTTP_PORT:-80}"
case "$HTTP_PORT" in
  ''|*[!0-9]*) err "HTTP 端口必须是数字"; exit 1 ;;
esac

HTTPS_PORT="443"
if [ "$TLS" != "3" ]; then
  read -r -p "HTTPS 端口（默认 443）: " HTTPS_PORT
  HTTPS_PORT="${HTTPS_PORT:-443}"
  case "$HTTPS_PORT" in
    ''|*[!0-9]*) err "HTTPS 端口必须是数字"; exit 1 ;;
  esac
  if [ "$TLS" = "1" ] && [ "$HTTP_PORT" != "80" ]; then
    err "Let's Encrypt HTTP 验证必须使用 80 端口"; exit 1
  fi
  if [ "$TLS" = "1" ] && [ "$HTTPS_PORT" != "443" ]; then
    err "Let's Encrypt HTTPS 必须使用 443 端口"; exit 1
  fi
fi

read -r -p "数据源端口（客户端统一用此端口，默认 8091）: " DS_PORT
DS_PORT="${DS_PORT:-8091}"
case "$DS_PORT" in
  ''|*[!0-9]*) err "数据源端口必须是数字"; exit 1 ;;
esac
if [ "$DS_PORT" = "$HTTP_PORT" ]; then
  err "数据源端口不能与网页版端口相同"; exit 1
fi

read -r -p "管理员用户名 默认 admin: " USER
USER="${USER:-admin}"
read -r -p "数据目录 默认 /srv/koodo/uploads: " DATAP
DATAP="${DATAP:-/srv/koodo/uploads}"

PASS="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 || true)"
EMAIL=""

# 根据 TLS 模式选择 compose 文件，模式 3 不绑定 443
COMPOSE_FILES="-f docker-compose.yml -f docker-compose.http.yml"
[ "$TLS" != "3" ] && COMPOSE_FILES="-f docker-compose.yml -f docker-compose.tls.yml"
DC="docker compose ${COMPOSE_FILES}"

gen_caddy(){
  local certline=""
  if [ "$TLS" = "2" ]; then
    mkdir -p reverse-proxy/certs
    info "生成自签证书..."
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout reverse-proxy/certs/privkey.pem \
      -out reverse-proxy/certs/fullchain.pem \
      -days 365 -subj "/CN=${HOST}" >/dev/null 2>&1 \
      || { err "openssl 生成证书失败"; exit 1; }
    certline="  tls /etc/caddy/certs/fullchain.pem /etc/caddy/certs/privkey.pem"
  elif [ "$TLS" = "1" ]; then
    read -r -p "Let's Encrypt 邮箱: " EMAIL
    certline="  tls ${EMAIL}"
  fi

  # 端口职责分离：
  #   容器 80（对外 HTTP_PORT）  -> Koodo 网页版
  #   容器 DS_PORT（对外同端口） -> Koodo 数据源 8080
  # 数据源不使用 /datasource 子路径：安卓端不接受路径前缀，只认官方的 host:port 格式。
  # 容器内监听端口必须与 compose 映射的容器端口一致；对外端口由映射决定。
  if [ "$TLS" = "3" ]; then
    cat > reverse-proxy/Caddyfile <<EOF
:80 {
  encode gzip
  reverse_proxy koodo:80
}

:${DS_PORT} {
  encode gzip
  reverse_proxy koodo:8080
}
EOF
  else
    cat > reverse-proxy/Caddyfile <<EOF
${HOST} {
${certline}
  encode gzip
  reverse_proxy koodo:80
}

${HOST}:${DS_PORT} {
${certline}
  encode gzip
  reverse_proxy koodo:8080
}
EOF
  fi
}

gen_caddy

cat > .env <<EOF
KOODO_IMAGE_TAG=ghcr.io/koodo-reader/koodo-reader:master
SERVER_USERNAME=${USER}
SERVER_PASSWORD=${PASS}
SYNC_HOST=${HOST}
SYNC_EMAIL=${EMAIL}
DATA_PATH=${DATAP}
HTTP_PORT=${HTTP_PORT}
HTTPS_PORT=${HTTPS_PORT}
DS_PORT=${DS_PORT}
TLS_MODE=${TLS}
COMPOSE_FILES="${COMPOSE_FILES}"
FREEZE=0
EOF

mkdir -p "$DATAP"
info "拉取镜像并启动服务..."
$DC pull
$DC up -d

# 生成对外访问信息
WEB_URL="http://${HOST}"
[ "$HTTP_PORT" != "80" ] && WEB_URL="http://${HOST}:${HTTP_PORT}"
[ "$TLS" != "3" ] && WEB_URL="https://${HOST}"
[ "$TLS" != "3" ] && [ "$HTTPS_PORT" != "443" ] && WEB_URL="https://${HOST}:${HTTPS_PORT}"

if [ "$TLS" = "3" ]; then
  DS_URL="http://${HOST}:${DS_PORT}"
else
  DS_URL="https://${HOST}:${DS_PORT}"
fi

ok "部署完成"
echo "---------------------------------------------"
echo "网页版:   ${WEB_URL}/"
echo "数据源:   ${DS_URL}   (Koodo 客户端填写此地址)"
echo "账号:     ${USER}"
echo "密码:     ${PASS}"
echo "---------------------------------------------"
echo "客户端 → 设置 → 数据源 → Docker → 填上方数据源地址 + 账号密码"
echo "注意：数据源地址不带任何路径后缀，就是 host:端口 的形式"
echo "运维：koodo-hub status / backup / upgrade / freeze"
echo "提示：生产环境建议运行 koodo-hub freeze 冻结版本"
