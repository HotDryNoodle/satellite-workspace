# Release Checklists

执行时逐项勾选；门禁命令与 [SKILL.md](../SKILL.md) 一致。

---

## Checklist A — 子仓库功能发布

适用：单个子仓库功能变更，可能需要父仓库跟进集成。

- [ ] 在目标子仓库完成变更并 commit
- [ ] push 子仓库到 remote
- [ ] （若对外发布）按 SemVer 在子仓库打 tag 并 push tag
- [ ] 父仓库：checkout submodule 到新 HEAD（或 `git submodule update`）
- [ ] `./scripts/update-lock.sh`
- [ ] `SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict`
- [ ] `SATELLITE_STRICT_VERSIONS=1 ./scripts/build-all.sh`
- [ ] `source install/env.sh && ./scripts/smoke-integration.sh`
- [ ] 父仓库 commit gitlinks + `VERSIONS.lock`

### Commit 示例（父仓库）

```text
chore(integration,task-manager): 将 task-manager 升至 v0.1.1

Goal:
- 父仓库集成锁跟进 task-manager 新 tag。

Changes:
- 更新 task-manager submodule gitlink
- 再生 VERSIONS.lock

version-check:
- ./scripts/update-lock.sh
- SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict
- SATELLITE_STRICT_VERSIONS=1 ./scripts/build-all.sh
- ./scripts/smoke-integration.sh
```

---

## Checklist B — SDK bump

适用：SDK 契约/API 变更；会同步 consumer `satellite-plugin-sdk.wrap`。

- [ ] 更新 `sdk/VERSION`（与即将打的 tag 数字一致）
- [ ] （schema breaking）更新 lock 中 `schema_version` 来源（`SATELLITE_LOCK_SCHEMA_VERSION` 或 lock 现有值 + 手动 bump 策略）
- [ ] 在 `sdk/` commit 并 push
- [ ] 在 `sdk/` 打 tag `vX.Y.Z` 并 push tag
- [ ] 父仓库 checkout `sdk/` 到新 HEAD
- [ ] `./scripts/update-lock.sh`
- [ ] 检查 `task-manager/subprojects/satellite-plugin-sdk.wrap` 及 `plugins/*/subprojects/satellite-plugin-sdk.wrap` 是否变更
- [ ] 在各 consumer 子模块内 commit wrap 变更并 push
- [ ] `SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict`
- [ ] `SATELLITE_STRICT_VERSIONS=1 ./scripts/build-all.sh`
- [ ] `source install/env.sh && ./scripts/smoke-integration.sh`
- [ ] 父仓库 commit：sdk gitlink + `VERSIONS.lock`（+ 其他已变 gitlink）

### Commit 示例（父仓库）

```text
chore(lock,sdk): 将 SDK 升至 v0.2.0 并同步 consumer wrap

Goal:
- 父仓库集成锁与 task-manager、mission-planer 的 SDK wrap revision 保持一致。

Changes:
- 更新 sdk submodule gitlink
- 再生 VERSIONS.lock
- consumer 子模块已单独 commit wrap 变更

version-check:
- ./scripts/update-lock.sh
- SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict
- SATELLITE_STRICT_VERSIONS=1 ./scripts/build-all.sh
- ./scripts/smoke-integration.sh
```

### Commit 示例（consumer 子模块，wrap 变更）

```text
build(deps): 同步 satellite-plugin-sdk.wrap 至 594c532

Goal:
- Meson wrap revision 与 workspace VERSIONS.lock 中 SDK commit 一致。

Changes:
- 更新 subprojects/satellite-plugin-sdk.wrap revision

version-check:
- meson subprojects download && meson setup build --reconfigure
```

---

## Checklist C — 正式发布（Release lock）

适用：对外发布封板；要求所有 submodule HEAD 均为 exact tag。

- [ ] 确认 `sdk/`、`task-manager/`、`plugins/mission-planer/`、`plugins/image-preprocess/` HEAD 均有 exact tag
- [ ] 各子仓库 tag 已 push 到 remote
- [ ] 父仓库 submodule 指向上述 tagged commit
- [ ] 确认各子模块 working tree clean（`update-lock.sh` 要求）
- [ ] `SATELLITE_RELEASE_LOCK=1 ./scripts/update-lock.sh`
- [ ] 确认 lock 中所有 `tag` 字段为真实 git tag（非 VERSION 推断）
- [ ] 若 wrap 变更：consumer 子模块 commit + push
- [ ] `SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict`
- [ ] `SATELLITE_STRICT_VERSIONS=1 ./scripts/build-all.sh`
- [ ] `source install/env.sh && ./scripts/smoke-integration.sh`
- [ ] 父仓库 commit gitlinks + `VERSIONS.lock`
- [ ] **不对父仓库打 tag**

### Commit 示例（父仓库）

```text
chore(release): 集成锁封板 v0.2.0（全子模块 exact tag）

Goal:
- 对外发布快照：所有 submodule 已 tag，lock 为 release lock。

Changes:
- 更新全部 submodule gitlinks 至 tagged commit
- SATELLITE_RELEASE_LOCK=1 再生 VERSIONS.lock

version-check:
- SATELLITE_RELEASE_LOCK=1 ./scripts/update-lock.sh
- SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict
- SATELLITE_STRICT_VERSIONS=1 ./scripts/build-all.sh
- ./scripts/smoke-integration.sh
```

---

## 快速对照：选哪个 checklist？

| 你正在做… | Checklist |
|-----------|-----------|
| 只改一个插件/服务，SDK 不变 | A |
| 改了 sdk/ 或 SDK 契约 | B |
| 对外发布公告，要求全 tag 封板 | C |
