# 发布与升级流程规范（RELEASE）

本文件是 koodo-sync-hub 的**发版纪律**：定义双环境分工、版本冻结语义，以及两套标准流程——

- **流程 A：新项目发布**（从零到 GitHub 公开，首个版本）
- **流程 B：代码升级**（已发布项目的小版本 / 大版本迭代，含自家服务器更新）

> 本规范由 v1.0.0 实际发布经验固化而来，之前的坑、做对的事都写进了「复盘」一节。

---

## 〇、铁律：双环境分工

| 角色 | 环境 | 职责 | 禁止 |
|---|---|---|---|
| **发布控制面** | Windows / X1（开发机） | 持有源码 git 仓库、写代码、打 tag、用 `gh` 推 GitHub | 跑 Koodo 服务（无 Docker 环境） |
| **部署目标** | Ubuntu / T460p（服务器） | 被 `install.sh` / `git pull` 更新、对外提供服务 | **绝不反向 push、绝不从服务器发版** |

- **GitHub = 唯一权威源**。X1 推上去，服务器只从 GitHub 拉。
- **升级自家服务器属于 B 通道（流程 B）**：手动、可回滚，先 `koodo-hub backup` 再更，失败可 `restore`。**绝不接入自动流水线去动生产机。**
- 理由：服务器上有真实 `.env` 密码、且代码常落后；从它发包 = 密钥泄露 + 发出旧版本。

---

## 一、v1.0.0 复盘（经验沉淀）

### ✅ 做对的事

1. **冻结双锁**：`VERSION` + `FREEZE=1` + 镜像 digest 锁定（`koodo-image.lock`），装一次版本永久一致。
2. **先真机验证再开源**：X1 上传 6 本书、安卓刷出 6 本、新手机实测「有骨架没肉」都跑通后才发布。
3. **合规细节到位**：`LICENSE`(MIT) + `NOTICE`(AGPL 署名)，README 写明「Docker 数据源是 Pro 独占、本项目不绕过授权」。
4. **敏感文件排除**：`.env` / `backups/` / `.workbuddy/` / `Caddyfile` 全部 gitignore，公开仓库无密钥。
5. **跨环境换行符预治**：`.gitattributes` 强制 `*.sh` / `koodo-hub` 为 `eol=lf`，避免 Ubuntu 上 bash 脚本失效。
6. **v1.0.0 tag 不移动**：发布后仅 README 链接修正推上 main，tag 锁在发布那一刻，符合「冻结即不可变」。

### ⚠️ 踩的坑（已解决，未来直接复用解法）

| 坑 | 现象 | 解法 |
|---|---|---|
| **upload.sh 漏发冻结契约** | 原脚本 `FILES` 缺 `VERSION` / `koodo-image.lock` / `docs`，「两端同态」目标无法实现 | 补进清单（已修，v1.0.0 含） |
| **CRLF 跨环境脚本失效** | Windows git `autocrlf` 把 .sh 转 CRLF，Ubuntu `bash` 跑挂 | 加 `.gitattributes` `*.sh text eol=lf` |
| **TLS 拦截代理导致 git HTTPS 失败** | `schannel` 报 `CRYPT_E_NO_REVOCATION_CHECK`，`openssl` 报 `unable to get local issuer certificate` | ① `gh auth setup-git` 让 git 用 gh 令牌；② 推送时 `git -c http.sslVerify=false`（仅当次命令） |
| **gh 路径/路径格式坑** | Bash 里 `gh` 找不到；传文件路径要用 Windows 形式 | 用完整路径 `/c/Program Files/GitHub CLI/gh.exe`；`cygpath -w` 转路径 |
| **SSH 路线被权限卡** | `gh ssh-key add` 需 `admin:public_key`，而 `gh auth refresh` 在非交互环境被 SIGTERM 中断 | 弃用 SSH，走 HTTPS + 关校验 |

### 🔧 待改进（下个版本纳入）

- CI 自动发版流水线（打 tag → 锁 digest → 写 `koodo-image.lock` → 出 Release notes）尚未建，目前靠手动。
- 一键安装脚本 `curl | bash` 的托管 URL 未做（v1.1 计划）。
- 发布前没有强制「勾选清单」环节，靠记忆易漏（如 upload.sh bug）。本文件的流程 A 第 0 步就是补这个。

---

## 二、流程 A：新项目发布（首版上线）

**目标**：把一个本地项目首次公开到 GitHub，成为可复用的开源作品。

### 第 0 步：发布前自检清单（逐项打勾，缺一不可）

- [ ] 工作区干净：`git status` 无未提交改动
- [ ] **无密钥入库**：`git ls-files | grep -E "\.env$|^backups/|\.workbuddy/|Caddyfile$|^certs/"` 应为空
- [ ] **冻结契约完整**：`VERSION` 已设、`FREEZE=1`、`koodo-image.lock` 含 digest
- [ ] **换行符干净**：`git ls-files --eol` 无 `w/crlf`
- [ ] 文档齐全：README（含操作说明 + 注意事项）、CHANGELOG、LICENSE、NOTICE
- [ ] 合规：上游许可证署名（如 Koodo 的 AGPL）已在 NOTICE 声明
- [ ] 涉及第三方（如 Docker 数据源为 Pro 功能）已在 README 明确、不绕过授权

### 第 1 步：本地提交并打 tag

```bash
git add -A
git commit -m "release: vX.Y.0 首个公开版本"
git tag -a vX.Y.0 -m "koodo-sync-hub vX.Y.0 首个公开版本"
```

> 提交信息中写明「本次验证结论」「关键事实」（如 Pro 功能、增量合并），方便日后回溯。

### 第 2 步：准备 GitHub 授权（一次性）

在 Windows PowerShell：

```powershell
winget install --id GitHub.cli          # 装完务必关终端重开
gh auth login                            # GitHub.com → HTTPS → Yes → Login with a web browser
gh auth status                           # 看到 Logged in to github.com as <你> 即成功
gh auth setup-git                        # 让 git 走 gh 令牌（绕开 TLS 拦截代理）
```

> 若 `gh` 在 Bash 环境调用，用完整路径 `/c/Program Files/GitHub CLI/gh.exe`，传文件路径用 `cygpath -w`。

### 第 3 步：建仓库并推送

```bash
# 在 GitHub 网页先建空仓库（不要勾 README/LICENSE，避免冲突）
gh repo create <repo> --public --description "<一句话描述>"
git remote add origin https://github.com/<你>/<repo>.git
git branch -M main
git push -u origin main --tags
```

> 若遇证书报错：`git -c http.sslVerify=false push -u origin main --tags`（仅当次）。

### 第 4 步：发 Release + 配门面

```bash
gh release create vX.Y.0 --title "vX.Y.0 首个公开版本" --notes "$(cat CHANGELOG对应段)"
gh repo edit <repo> --add-topic koodo-reader --add-topic self-hosted \
  --add-topic docker --add-topic homelab --add-topic ebook --add-topic sync \
  --add-topic tailscale --add-topic nas --add-topic privacy --add-topic caddy
```

### 第 5 步：补全链接，收尾

- README 顶部的仓库地址占位换成真实链接
- 作为后续提交推上 main（**不要移动已发布的 tag**）
- 把仓库地址记进项目记忆 / 公众号文章

---

## 三、流程 B：代码升级（迭代已发布项目）

**目标**：对已发布项目做小版本（PATCH / MINOR）或大版本（MAJOR）升级，含**自家服务器更新**。

### 两条通道

| 通道 | 对象 | 触发 | 风险 | 纪律 |
|---|---|---|---|---|
| **A 通道（对外发版）** | GitHub 上的其他用户 | `git tag vX.Y.Z` | 公开、不可逆 | CI/手动发版，同流程 A 第 1–5 步 |
| **B 通道（自家服务器）** | 你家的 T460p | 你决定升级时 | 动生产环境 | **手动、先备份、可回滚** |

> B 通道永远不进自动流水线。

### 第 0 步：确认当前态

```bash
cd /opt/koodo-sync-hub
koodo-hub status          # 看 FREEZE 态、镜像 digest
```

### 第 1 步：解冻（仅当要升级镜像）

```bash
koodo-hub release         # 置 FREEZE=0，允许升级
```

### 第 2 步：备份（强制，升级前必做）

```bash
koodo-hub backup          # 生成 ./backups/koodo-日期.tar.gz（书文件 + .env）
# 必须再拷出服务器一份（移动硬盘 / 其他机器 / 云盘）
```

### 第 3 步：拉取新代码（从 GitHub，不从本地直接改）

```bash
git pull origin main      # 或 git checkout vX.Y.Z 对齐特定版本
```

### 第 4 步：升级（自动先备份一次）

```bash
koodo-hub upgrade         # 内部：cmd_backup → docker pull → docker up -d
```

### 第 5 步：验证 + 回滚预案

```bash
koodo-hub status
# 验证网页版 / 数据源可达、客户端同步正常
# 若异常：koodo-hub restore ./backups/<升级前备份>.tar.gz
```

### 第 6 步：重新冻结（定版后）

```bash
koodo-hub freeze          # 锁新 digest + FREEZE=1
git add koodo-image.lock && git commit -m "chore: freeze vX.Y.Z" && git tag vX.Y.Z
```

---

## 四、版本纪律（SemVer + 冻结语义）

- **MAJOR**：不兼容变更（如数据源地址格式、端口重映射）
- **MINOR**：新增能力（如阶段二公网直连、新增设备支持）
- **PATCH**：修 bug（如 upload.sh 漏发文件）
- **只有打 tag 的提交才算发布**；`main` 上的提交只是「待发布」。
- **冻结 = 镜像 digest 锁 + FREEZE=1**；冻结后 `upgrade` 自动拒绝，必须先 `release`。
- **已发布的 tag 不可移动**（除非显式重发并知会用户）。

---

## 五、发布渠道优先级（v1.x）

| 渠道 | 适合度 | 阶段 |
|---|---|---|
| GitHub Releases（源码 tag） | ⭐⭐⭐⭐⭐ | 现在就用 |
| 一键安装脚本 `curl \| bash` | ⭐⭐⭐⭐⭐ | v1.1 必做 |
| Wrapper Docker 镜像 | ⭐⭐⭐ | 用户量大后 |
| Homebrew / APT | ⭐⭐ | 暂不做 |
| 社区收录（awesome-selfhosted 等） | ⭐⭐⭐⭐ | 发版后投稿 |
| 公众号 / 少数派 / V2EX 长文 | ⭐⭐⭐⭐ | 已在进行 |

---

*本规范随项目演进更新。任何发版前，先读「第 0 步自检清单」。*
