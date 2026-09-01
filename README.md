# koodo-sync-hub

> 一条命令，在自有 Ubuntu / Debian 服务器上搭建 Koodo Reader 的私有同步中枢，
> 实现电脑、手机、平板多端无缝续读。

[English](#english) | 中文

---

## 这是什么

**koodo-sync-hub** 是一套围绕 [Koodo Reader](https://github.com/koodo-reader/koodo-reader)
官方 Docker 镜像的**部署与运维工具集**（不是 fork）。它帮你解决自建同步最麻烦的几件事：

- 一键安装（`install.sh` 交互向导：TLS 三模式、自动生成强密码）
- 一套运维命令（`koodo-hub`：状态 / 备份 / 恢复 / 升级 / 卸载 / 冻结 / 同步）
- 多端同步规约与客户端配置说明（Koodo 官方没讲清的部分）

数据完全私有，不依赖任何第三方云盘。

## 当前状态

| 项目 | 值 |
|------|-----|
| 版本 | v1.0.0 |
| 冻结状态 | 已冻结（`FREEZE=1`） |
| Koodo 镜像 | `ghcr.io/koodo-reader/koodo-reader@sha256:6db5e92f…`（v1.0.0 锁定） |
| 生产验证 | Ubuntu LTS + Tailscale，TLS 模式 3，网页版 8090 / 数据源 8091，已通过 |
| 仓库地址 | https://github.com/duyz2026/koodo-reader-selfhosted |

版本冻结机制见 [`docs/03-版本冻结与同步.md`](docs/03-版本冻结与同步.md)，
关键步骤图示见 [`docs/images/preview.html`](docs/images/preview.html)。

## 快速开始（30 秒）

```bash
sudo bash install.sh
```

向导会问你：访问地址（公网 IP 或域名）、TLS 模式、管理员账号、数据目录。
完成后它会输出：

```
网页版:   http://你的地址:8090/
数据源:   http://你的地址:8091   ← Koodo 客户端填这个
账号:     admin
密码:     （自动生成，请记下）
```

> **数据源使用独立端口**（默认 8091），不带任何路径后缀。
> 安卓端不接受 `/datasource` 这类路径前缀，只认官方的 `host:port` 格式，
> 所以桌面、网页、安卓、iOS 统一填 `http(s)://你的地址:8091`。

客户端（Koodo Reader 桌面版 / 手机版）→ 设置 → 数据源 → 选 Docker →
填上面的「数据源」地址 + 账号密码，即可多端同步。

生产环境部署步骤与验证清单见 [`docs/04-生产环境部署手册.md`](docs/04-生产环境部署手册.md)。

## 操作说明（日常使用）

**1. 安装**
```bash
sudo bash install.sh        # 向导问：访问地址 / TLS 模式 / 账号 / 数据目录
```
装完输出网页版地址（8090）与数据源地址（8091，不带路径）。

**2. 客户端连接（桌面 / 手机 / 平板）**
Koodo Reader → 设置 → 数据源 → 选「Docker」→ 填：
- 地址：`http(s)://你的地址:8091`（**不要**加 `/datasource` 之类路径）
- 账号 / 密码：install.sh 生成的 admin 与随机密码

**3. 导入图书**
客户端「导入」把书传进自建数据源。建议分批导入（5G 以上书库别一次性怼，
反代已配 10 分钟超时，但逐本更稳）。导入后在其他设备点「导入云端图书」即可拉取。

**4. 跨设备续读（进度 / 笔记）**
- 想让阅读进度、笔记、高亮、书签跨设备同步：在客户端开启 **Koodo Sync**（官方云，加密）。
- 只想把书放在自己服务器、完全不上云：关掉 Koodo Sync，仅保留自建数据源
  （代价是进度/笔记不跨设备同步）。

**5. 备份与恢复（务必做）**
```bash
koodo-hub backup                       # 生成 ./backups/koodo-日期.tar.gz（书文件 + .env）
koodo-hub restore ./backups/xxx.tar.gz # 从备份恢复
```
备份包默认在服务器本地，**必须再拷出服务器一份**（移动硬盘 / 另一台机 / 云盘），
否则服务器磁盘损坏书即丢失。升级前强制先备一份。

**6. 升级与冻结**
```bash
koodo-hub status          # 看服务状态、冻结态、镜像 digest
koodo-hub freeze          # 锁镜像 digest + FREEZE=1
koodo-hub release         # 解冻，允许升级
koodo-hub upgrade         # 升级上游镜像（冻结态自动拒绝）
koodo-hub uninstall       # 卸载（可选保留数据）
```

## 版本冻结（重要）

定稿一个版本后，可以把它**冻结**并让本地电脑与服务器保持同一版本：

```bash
koodo-hub freeze          # 锁 Koodo 镜像 digest + 置 FREEZE=1
koodo-hub sync --to v0.2.0   # 本地/服务器 checkout 同一 tag，同态固化
koodo-hub status          # 查看冻结态、镜像 digest
```

详见 `docs/03-版本冻结与同步.md`。

## 运维命令

| 命令 | 作用 |
|------|------|
| `koodo-hub status` | 服务状态 + 冻结态 + 当前镜像 |
| `koodo-hub backup` | 备份数据卷到 `./backups` |
| `koodo-hub restore <file>` | 从备份恢复 |
| `koodo-hub upgrade` | 升级（冻结态自动拒绝） |
| `koodo-hub uninstall` | 卸载（可选保留数据） |
| `koodo-hub freeze` / `release` | 冻结 / 解冻 |

## 注意事项（必读）

1. **Docker 数据源是专业版（Pro）功能。** Koodo Reader 的 Docker / WebDAV 等云端同步
   均为 **Pro 独占**（约 ¥25/年），免费版不支持「自建数据源」。部署前请确认已订阅，
   否则客户端连得上、书存不进。本项目不提供也不绕过授权。
2. **Koodo Sync 与自建数据源是两条独立链路。** Koodo Sync（官方云）只同步
   *阅读进度 / 笔记 / 高亮 / 书签*；*图书与封面* 只走你自建的 8091 数据源。
   官方云挂了不会丢你的书，但服务器挂了官方云也救不回书——书的安危 100% 取决于你的备份。
3. **必须做「离站」备份。** `koodo-hub backup` 只存在服务器本地，盘坏一起没。
   至少留一份拷贝在服务器之外（移动硬盘 / 其他机器 / 云盘）。恢复命令见上。
4. **数据源用独立端口、不带路径前缀。** 所有客户端统一填 `http(s)://HOST:8091`，
   安卓端不接受 `/datasource` 这类子路径，桌面端也建议保持一致避免混乱。
5. **同步是增量合并，非整包覆盖。** 多端可各自上传自己的增量；但**多端离线同时改同一条
   笔记可能冲突**，规范做法是「变更端先同步，其余设备依次同步」。
6. **大文件上传需足够超时。** 反代已配 10 分钟响应/读写超时；超大书库仍建议分批导入。
7. **许可证与署名。** 本仓库以 **MIT** 发布，仅编排上游镜像、不修改其源码；
   Koodo Reader 为 **AGPL-3.0**，署名见 [NOTICE](NOTICE)。本工具与 Koodo 官方无隶属关系，
   不声称其背书；若自行修改并再分发 Koodo 源码，须遵循 AGPL-3.0 开源。
8. **安全。** `.env` 含管理员密码，**绝不入库**；管理端口不要无防护暴露公网。

## 路线图（2.0）

v1.0.0 的连接方式是 **Tailscale 虚拟局域网**，已在 Windows 与安卓真机验证通过。

2.0 计划改为 **公网直连 + HTTPS**，让 iPad、Kindle 等无法安装 Tailscale 的设备也能接入，所有设备统一填一个 URL、不依赖任何 VPN。

前期调研已完成（含国内网络环境的特殊约束与备选路径），详见 [`docs/07-阶段二准备纪要（iPad与Kindle接入）.md`](docs/07-阶段二准备纪要（iPad与Kindle接入）.md)。

> 2.0 的改动不会影响 v1.0.0 的行为，将在 v1.0.0 发布后另起分支推进。

## 合规说明

本仓库自身采用 **MIT**；它只编排 Koodo Reader 官方镜像、不修改其源码。
Koodo Reader 为 **AGPL-3.0**，署名见 [NOTICE](NOTICE)。

## 目录结构

```
├── install.sh            # 一键安装向导
├── koodo-hub             # 运维 CLI
├── docker-compose.yml    # 主栈：koodo-reader + caddy
├── .env.example          # 配置项示例
├── reverse-proxy/        # Caddyfile 模板与生成的配置/证书
├── docs/                 # 规划与调研文档
│                         #   01 需求 / 02 开源化 / 03 冻结 / 04 部署手册
│                         #   05 公众号推文 / 06 技术复盘 / 07 阶段二调研（iPad 与 Kindle）
└── .github/              # CI 与 issue/PR 模板
```

---

## English

**koodo-sync-hub** is a deployment & ops toolkit around the official Koodo Reader
Docker image (not a fork). One command brings up a private sync hub for Koodo
Reader across PC / phone / tablet.

```bash
sudo bash install.sh
```

Then point Koodo Reader clients (Desktop / Mobile) → Settings → Data Source → Docker
→ the printed data-source URL + credentials.

Freeze a version and keep your laptop and server in sync:

```bash
koodo-hub freeze
koodo-hub sync --to v0.2.0
```

This repo is MIT; it only orchestrates the upstream AGPL-3.0 image. See [NOTICE](NOTICE).

### Important notes (EN)

- The Docker data source is a **Koodo Reader Pro** feature (paid, ~¥25/yr). The free
  edition cannot store books on a self-hosted source.
- **Koodo Sync** (official cloud) syncs *progress/notes/highlights/bookmarks only*;
  *books & covers* go through your self-hosted source at port `DS_PORT` (default 8091),
  with **no path prefix**.
- **Back up off-site.** `koodo-hub backup` lives on the server; copy it elsewhere or you
  lose everything if the disk dies. Books are NOT stored in the official cloud.
- Sync is **incremental merge**, not full overwrite.
- This project is not affiliated with Koodo Reader and does not claim its endorsement.
