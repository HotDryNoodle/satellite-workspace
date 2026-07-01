# SemVer and Tags Reference

## SemVer 通则（行业）

格式：`MAJOR.MINOR.PATCH`（如 `0.2.1`）。

| 变更 | 升位 | Conventional Commit 信号 |
|------|------|--------------------------|
| 不兼容 API/契约 | MAJOR | `feat!:`、`fix!:` 或 footer `BREAKING CHANGE:` |
| 向后兼容新功能 | MINOR | `feat:` |
| 向后兼容修复 | PATCH | `fix:` |
| 文档/测试/构建 | 通常不升位 | `docs:`、`test:`、`build:`、`ci:`、`chore:` |

`0.y.z` 阶段：MINOR 仍可用于新功能；breaking 变更可升 MINOR 或 MAJOR，团队应保持一致。

## 本仓库 tag 规则

- **格式**：`v` + SemVer（如 `v0.2.1`）
- **位置**：在**子仓库**创建并 push，不在父仓库打 product tag
- **父仓库**：仅记录 gitlink + `VERSIONS.lock` 中的 `commit` / `tag` 字段

### `update-lock.sh` 的 tag 解析（`submodule_tag()`）

**Release lock**（`SATELLITE_RELEASE_LOCK=1`）：

- 每个 submodule HEAD **必须**满足 `git describe --tags --exact-match`
- 否则脚本报错退出

**Integration lock**（默认）：

1. 若 HEAD 有 exact tag → 使用该 tag
2. 否则若存在 `VERSION` 文件 → 使用 `v{VERSION}`（如文件内容为 `0.1.0` → `v0.1.0`）
3. 否则 fallback `v0.1.0`

### SDK 特有字段

| 字段 | 位置 | 说明 |
|------|------|------|
| `version` | `sdk/VERSION`（无 `v` 前缀）、lock `[satellite-plugin-sdk] version` | 须与 tag 中的 SemVer 数字一致 |
| `schema_version` | lock `[satellite-plugin-sdk] schema_version` | 契约 schema breaking 时手动 bump |
| `wrap_revision` | lock | 等于 SDK commit SHA |

发布 SDK 时：`sdk/VERSION`、`git tag vX.Y.Z`、lock `version` 三者对齐。

## 升位决策示例

| 变更 | 升位对象 | 父仓库动作 |
|------|----------|------------|
| task-manager 内部逻辑，不改 SDK 契约 | 仅 `task-manager` tag | 更新 gitlink + lock |
| mission-planer 插件 bugfix | 仅 `plugins/mission-planer` tag | 更新 gitlink + lock |
| SDK envelope schema breaking | `sdk` MAJOR + `schema_version` | SDK bump 全流程 + consumer wrap |
| SDK 向后兼容新 API | `sdk` MINOR | SDK bump 全流程 |
| 仅父仓库 `scripts/` 或 CI | 无子模块 tag | 父仓库 commit；gitlink 不变则 lock 可不变 |
| 第三方 `nlohmann_json` wrap 变更 | 无 semver tag | lock 中 `third_party.nlohmann_json.wrap_hash` 更新 |

## 打 tag 命令示例

在子仓库内（以 sdk 为例）：

```bash
cd sdk
# 确认 VERSION 与即将打的 tag 一致
cat VERSION   # 期望 0.2.0
git tag -a v0.2.0 -m "v0.2.0: <summary>"
git push origin v0.2.0
git push origin HEAD
```

其他子仓库同理；tag 名统一 `vMAJOR.MINOR.PATCH`。

## Release lock 与 Integration lock 选择

| 场景 | 推荐模式 |
|------|----------|
| 日常 PR 合并、CI 绿 | Integration lock |
| 对外发布公告、交付快照 | Release lock |
| 子模块 HEAD 尚未全部 tag | Integration lock only |

Release lock 后 lock 文件中所有 `tag = "..."` 均为真实 git tag，而非 VERSION 推断值。
