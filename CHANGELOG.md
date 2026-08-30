# Changelog

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/) 规范，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

## [1.0.0] - 2026-08-31

首个公开版本。生产环境（T460p / Ubuntu LTS / Tailscale）已通过完整验证：网页版 8090 + 数据源 8091，
X1 桌面端 6 本书上传成功，安卓手机「导入云端图书」成功刷出全部 6 本，多端同步链路打通。

### Added
- 客户端实测同步通过：桌面 + 安卓手机经自建数据源 8091 互相同步图书
- README 新增「操作说明」与「注意事项」两节（覆盖 Pro 功能、Koodo Sync 与自建数据源的分工、备份强制要求、端口规范、增量合并、许可证与署名）
- `.env.example` 的 `KOODO_IMAGE_TAG` 默认锁定为 v1.0.0 冻结 digest，保证一次安装版本永久一致

### Changed
- 版本号升级至 1.0.0，`FREEZE=1`（升级需先 `koodo-hub release`）

### Verified
- Caddy 10 分钟上传超时修复生效，大书不再被 502 掐断
- 确认 Docker 数据源为 Koodo **专业版（Pro）** 功能（¥25/年），免费版不支持
- 确认同步为**增量合并**，非整包覆盖

## [0.1.3] - 2026-08-30

### Changed
- **架构变更：数据源改用独立端口，移除 `/datasource` 子路径**。实测发现安卓端不接受路径前缀，只认官方示例的 `host:port` 格式（v0.1.2 的 `http://host:8090/datasource` 在安卓端必然失败）。改为端口职责分离：网页版用 `HTTP_PORT`，数据源用 `DS_PORT`（默认 8091），全平台统一填 `http(s)://host:8091`
- `install.sh` 新增「数据源端口」交互项（默认 8091），并校验不能与网页版端口相同
- `install.sh` 生成的 Caddyfile 改为两个站点块：容器 80 → `koodo:80`（网页版），容器 `DS_PORT` → `koodo:8080`（数据源）
- 安装完成输出的数据源地址改为 `http(s)://host:DS_PORT`，不带路径后缀

### Added
- `.env` / `.env.example` 新增 `DS_PORT` 参数
- `docker-compose.http.yml` / `docker-compose.tls.yml` 均映射数据源端口
- `docs/04` §7 从「回退方案」改为「端口职责说明」，补充客户端配置要点（先上传再下载、开启自动下载云端图书）

### Fixed
- 修正 `docs/01` 中「Koodo 免费版可用 Docker 数据源」的错误前提：Docker / WebDAV 等云端同步均为**专业版功能**（￥25/年），免费版不支持
- 修正同步机制描述：官方为**增量合并**，任何设备均可作为上传端；此前「整包覆盖、一端写入他端拉取」的表述作废

## [0.1.2] - 2026-08-30

### Fixed
- `install.sh`：生成随机密码时 `tr </dev/urandom | head -c 16` 触发 `pipefail` 陷阱（`tr` 收到 SIGPIPE 退出码非零），导致脚本静默退出、`.env` 未生成
- `install.sh`：TLS 模式 3 的 Caddyfile 站点地址写死为 `${HOST}:80`，客户端带自定义端口（如 8090）访问时 Host 头不匹配被拒，改为 `:80` 匹配任意 Host
- `install.sh`：数据源路由中 `handle_path` 已自带前缀剥离，又叠加 `uri strip_prefix` 导致剥两次；去掉多余指令，并将 `/datasource/*` 改为 `/datasource*` 以覆盖无尾斜杠请求
- `koodo-hub freeze`：误用容器 ID 读取 `.RepoDigests`（该属性属于镜像而非容器），导致冻结始终报「无法获取 digest」

### Changed
- `koodo-hub freeze` 现在会同步将 `.env` 中的 `KOODO_IMAGE_TAG` 改写为 digest 形式。此前仅写锁文件，镜像 tag 仍可能被上游重推而漂移，冻结形同虚设

### Added
- `koodo-image.lock`：记录已冻结的镜像 digest
- `VERSION`：内部版本号与冻结状态记录（含生产验证环境信息）
- `docs/images/`：部署拓扑、部署五步、版本冻结双锁三张 4:3 图示，附浏览器预览页 `preview.html`

### Verified
- 在 T460p（Ubuntu LTS / docker compose v2.31.3 / Tailscale）完成生产部署：TLS 模式 3 + 端口 8090
- 网页版返回 HTTP 200，数据源服务可达
- `koodo-hub backup` 与 `koodo-hub freeze` 均执行成功，镜像已锁定为 digest 形式

## [0.1.1] - 2026-08-29

### Added
- 支持自定义 HTTP/HTTPS 端口，解决 80/443 已被 openresty/nginx 占用的问题
- `docker-compose.http.yml` / `docker-compose.tls.yml` 两种 override，模式 3 不再强制绑定 443
- `.env` 记录 `TLS_MODE` 与 `COMPOSE_FILES`，`koodo-hub` 自动读取对应 compose 文件组合

## [0.1.0] - 2026-08-29

### Added
- 仓库骨架：LICENSE(MIT)、NOTICE(AGPL 署名)、CI、issue/PR 模板、贡献/安全规范
- `docker-compose.yml` 主栈：koodo-reader（数据源 8080 + 网页版 80）+ caddy 反代
- `install.sh` 交互式安装向导：TLS 三模式（域名+Let's Encrypt / 自签 / 纯 HTTP）、自动生成强密码
- `koodo-hub` 运维 CLI：status / backup / restore / upgrade / uninstall
- 版本冻结能力：freeze / release / sync，基于镜像 digest 双锁 + git tag 同态

[1.0.0]: https://github.com/koodo-sync-hub/koodo-sync-hub/releases/tag/v1.0.0
[0.1.0]: https://github.com/koodo-sync-hub/koodo-sync-hub/releases/tag/v0.1.0
