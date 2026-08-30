# 开源化与 GitHub 项目规划 — Koodo Sync Hub（暂定名）

> 版本：v0.1（草案） 日期：2026-08-28
> 上游文档：`01-需求与总体框架.md`

---

## 1. 产品定位

**一句话定位**：一条命令，在任何 Ubuntu/Debian 服务器上搭建 Koodo Reader 的私有同步中枢，实现手机、电脑、平板多端无缝续读。

- **它是什么**：围绕 Koodo Reader 官方 Docker 镜像的**部署与运维工具集**（编排 + 脚本 + 文档），不是 Koodo 的 fork。
- **目标用户**：想自建 Koodo 同步但不想折腾 Docker/反代/证书/备份的普通用户；自托管爱好者（self-hosted 社区）。
- **核心卖点**：
  1. 一键安装（交互式向导：IP/域名、TLS 三模式、自动生成强密码）
  2. 一套生命周期命令：安装 / 状态 / 备份 / 恢复 / 升级 / 卸载
  3. 内置多端同步规约与客户端配置图文（Koodo 官方文档没讲清的部分）
- **后续差异化路线**：平板接入指南 → Kindle 书库推送模块（阶段二成果反哺开源）。

## 2. 开源合规（红线，先定死）

Koodo Reader 采用 **AGPL-3.0**，官方明确要求：使用其代码必须同样以 AGPL 开源 + 显著署名 + 链接仓库，且不提供商用授权。因此：

| 事项 | 决策 |
|------|------|
| 本仓库内容 | 只编排官方镜像（`docker pull`）、不复制 Koodo 源码 → 本仓库自身采用 **MIT** |
| 署名义务 | README 首屏 + NOTICE 文件显著声明"基于 Koodo Reader"，链接 github.com/koodo-reader/koodo-reader |
| 未来若 fork/修改 Koodo 源码 | 必须拆独立仓库，采用 **AGPL-3.0**，与本工具仓库隔离 |
| 商用提示 | 文档注明 Koodo 本身无商用授权，使用者自担合规责任 |
| 镜像分发 | 不二次分发镜像，仅引用 ghcr.io 官方地址，规避 AGPL 传染歧义 |

## 3. 命名与品牌（三选一，定后不再改）

1. **koodo-sync-hub** —— 直白，SEO 好，推荐
2. **koodo-selfhost** —— 定位精确
3. **ReadNest** —— 有品牌感但脱离 Koodo 搜索流量

配套：repo 名 = 项目名；CLI 命令统一为 `koodo-hub <action>`。

## 4. 仓库结构

```
koodo-sync-hub/
├── README.md                # 中英双语，30 秒快速开始 + GIF 演示
├── README_EN.md
├── LICENSE                  # MIT
├── NOTICE                   # AGPL 署名：基于 Koodo Reader
├── CHANGELOG.md             # 语义化版本 + Keep a Changelog 格式
├── docker-compose.yml       # 主栈：koodo-reader + caddy（+ 可选 sftpgo profile）
├── .env.example             # 全部配置项，带中文注释
├── install.sh               # 一键安装向导（交互式）
├── upgrade.sh               # 升级：备份→拉新镜像→重建→健康检查
├── uninstall.sh             # 卸载（可选保留数据）
├── cli/koodo-hub            # 生命周期命令：status/backup/restore/logs/restart
├── reverse-proxy/           # Caddyfile 模板 ×3（域名+LE / 自签 / 纯HTTP内网）
├── backup/                  # backup.sh、restore.sh、cron 安装脚本
├── docs/
│   ├── 部署指南.md          # 分场景：公网IP / 域名 / 内网穿透
│   ├── 客户端配置.md        # PC/手机/平板，含截图
│   ├── 同步规约.md          # 多端同步操作纪律：变更端先同步，其余设备依次同步
│   ├── 专业版说明.md        # Docker/WebDAV 同步为专业版功能（￥25/年），免费版替代路径
│   ├── 备份与恢复.md
│   └── roadmap.md           # 含阶段二 Kindle 路线
├── .github/
│   ├── workflows/           # ci.yml（shellcheck/hadolint/yamllint）、release.yml
│   ├── ISSUE_TEMPLATE/      # bug 报告（含部署模式/系统版本）、功能建议
│   └── PULL_REQUEST_TEMPLATE.md
├── CONTRIBUTING.md
├── SECURITY.md              # 漏洞报告方式 + 默认安全基线说明
└── .gitignore               # .env、数据卷目录绝不入库
```

**铁律**：`.env`（含密码）、`data/`、`backups/` 永远进 `.gitignore`；安装脚本禁止写死任何弱默认密码。

## 5. 功能版本规划（语义化版本）

| 版本 | 内容 | 验收标准 |
|------|------|----------|
| **v0.1 MVP** | docker-compose 主栈 + install.sh 向导（TLS 三模式）+ 基础 README | 全新 Ubuntu 22.04/24.04 虚拟机，一条命令从零到手机可同步 |
| **v0.2** | `koodo-hub` CLI（status/backup/restore/logs）+ cron 自动备份 + 升级/卸载脚本 | 删库后凭备份完整恢复书库与进度 |
| **v0.3** | 客户端配置图文全量（PC/iOS/Android）+ 同步规约文档 + FAQ | 第三方用户按文档零提问完成三端配置 |
| **v1.0 正式发布** | CI 全绿 + 双语 README + 演示 GIF + 提交 awesome-selfhosted PR | GitHub Release 打 tag，社区可推广 |
| **v1.x（阶段二反哺）** | 平板接入文档 → Kindle 书库推送模块（Send to Kindle 流程）→ 可选多用户（SFTPGo profile） | 按阶段二实际成果滚动 |

## 6. 工程规范

- **Shell**：bash + POSIX 兼容；`set -euo pipefail`；全部过 shellcheck
- **CI**（GitHub Actions）：PR 触发 shellcheck / hadolint / yamllint；tag `v*` 触发 Release（自动生成 CHANGELOG 摘要 + 仓库 tarball）
- **测试**：维护"冒烟测试清单"——全新 VM 安装→三端模拟（浏览器 UA 模拟）→备份→恢复→升级；每次发布前人工过一遍
- **提交**：Conventional Commits（feat/fix/docs/chore），CHANGELOG 自动累积
- **配置与数据分离**：一切可变项进 `.env` + named volumes，保证跨版本升级可复用

## 7. 共享与推广渠道

1. GitHub：Topics 打满（`koodo-reader` `self-hosted` `ebook` `webdav` `sync` `docker`）
2. 向 **awesome-selfhosted** 提 PR（最精准的自托管流量入口）
3. Koodo Reader 官方 Discussions/README 提及（礼貌自荐，靠官方背书）
4. 国内渠道：少数派/V2EX/恩山 论坛发部署教程（附 repo 链接）
5. GitHub Discussions 开通，分类：部署求助 / 功能建议 / 展示

## 8. 升级复用机制（对应"能升级复用"的诉求）

- **升级**：`upgrade.sh` = 自动备份 → `docker compose pull` → 重建 → 健康检查 → 失败提示回滚步骤；上游镜像 breaking change 在 CHANGELOG 中标注兼容矩阵
- **复用**：`.env.example` 全参数化（端口/路径/密码/TLS 模式），换服务器 = 拷贝 `.env` + 备份包 + 重跑 install.sh
- **迁移**：v0.2 起 `restore.sh` 支持从备份包在新机器完整重建（书库+进度+配置）
- **冻结（与升级对称，2026-08-29 新增）**：见 `docs/03-版本冻结与同步.md`——`FREEZE` 开关 + `koodo-image.lock`（digest 级）+ `VERSION`（git tag 级）双锁；本地与服务器 `koodo-hub sync --to <tag>` 同态固化，杜绝版本分叉。与"升级"共存：`release` 解冻 → `upgrade` 推进 → `freeze` 再固化。

## 9. 里程碑与节奏

| 节点 | 内容 |
|------|------|
| R0 | GitHub 建仓、LICENSE/NOTICE/CI 骨架、推首个 commit |
| R1 | v0.1 MVP：在自有 Ubuntu 服务器上先行落地（即本项目的 M1 部署成果直接转化为 MVP） |
| R2 | v0.2：备份/恢复/CLI（对应本项目 M3） |
| R3 | v1.0：文档完善 + 正式发布 + 推广 |

> 私有部署与开源项目**同源共生**：自己服务器就是第一个生产环境，每个里程碑既是个人项目交付也是开源版本迭代。

## 10. 风险

| 风险 | 对策 |
|------|------|
| AGPL 边界误判 | 坚持"只编排不改码"；任何 Koodo 代码修改走独立 AGPL 仓库 |
| 上游镜像 breaking change | CI 中固定镜像 digest 测试 + 升级前备份强制 |
| 弱口令导致开源用户被打 | 安装向导强制生成随机密码；SECURITY.md 提示防火墙基线 |
| 维护精力不足 | v1.0 后功能冻结，只修 bug + 跟进上游，roadmap 明示 |

---

**待老板拍板**：① 项目名（推荐 koodo-sync-hub）；② GitHub 账号下建仓时间；③ 推广节奏（R3 是否立即做国内渠道）。
