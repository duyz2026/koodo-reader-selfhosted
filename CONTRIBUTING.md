# 贡献指南

感谢你考虑为 koodo-sync-hub 做贡献。

## 开发约定

- 脚本使用 Bash，目标 POSIX 兼容；所有脚本必须通过 `shellcheck`。
- 提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/)：
  `feat:` / `fix:` / `docs:` / `chore:` / `refactor:`。
- 版本号遵循语义化版本；每次发布更新 `CHANGELOG.md`。

## 工作流程

1. Fork 并在 `main` 之外开分支。
2. 改动后本地过一遍 CI 对应检查：`shellcheck install.sh koodo-hub`、`yamllint docker-compose.yml`。
3. 提交 PR，描述**动机**与**测试方式**。
4. 维护者 review 后合并；发布时打 `vX.Y.Z` tag。

## 合规红线

- **不要**把 Koodo Reader 的源码复制进本仓库。本仓库只编排官方镜像。
- 若需修改 Koodo 自身代码，请在独立的 AGPL-3.0 仓库中进行。
- 任何 secrets（`.env`、证书）不得提交。

## 范围

v1.0 后功能冻结，仅接受 bug 修复与上游跟进；新功能请在 Discussions 提议后再实现。
