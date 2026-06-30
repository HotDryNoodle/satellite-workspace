---
name: commit-message-policy
description: Commit policy skill。用于在父仓库 satellite-workspace 提交、PR 或集成封板阶段加载结构化 commit message 约束。
version: 1.1.0
depends_on: []
tools:
  - skills/commit-message-policy/references/summary-and-examples.md
  - .githooks/commit-msg
  - scripts/validate_commit_message.py
  - scripts/install_commit_msg_hook.sh
triggers:
  - commit
  - publish
  - pull-request
---

# Commit Message Policy

## Scope

- 约束 **父仓库** `satellite-workspace` 根目录，以及工作区内子模块（`sdk/`、`task-manager/`、`plugins/*`）的 git commit。
- `install_commit_msg_hook.sh` 为父仓库与子模块设置 `core.hooksPath`，统一调用父仓库的 `validate_commit_message.py`。
- 子模块单独 clone 时不受本规范约束，需自行安装或沿用各自仓库规范。

## TL;DR

- 第一行必须匹配 `<type>(<scope>): <summary>`，其中 `scope` 可选。
- 必须按顺序包含 `Goal`、`Changes`、`version-check` 三个 section。
- 校验入口：`.githooks/commit-msg` 和 `scripts/validate_commit_message.py`
- 安装入口：`bash scripts/install_commit_msg_hook.sh`

## Load When

- 在父仓库创建 git commit
- 整理提交信息用于 PR 或集成晋升
- 检查提交信息是否符合仓库规范

## Must Follow

- `type` 只能使用 `feat|fix|refactor|docs|test|build|ci|chore|perf`
- `summary` 长度限制为 `1..72`
- 每个 section 至少一行非空内容；无内容时写 `n/a`
- section 内容建议中文；`version-check` 可写命令或 `n/a` / `docs-only, not run`
- 详细模板与示例以 `references/summary-and-examples.md` 为准

## Enforced By

- Hook: `.githooks/commit-msg`
- Validator: `python3 scripts/validate_commit_message.py <message-file>`
- Install: `bash scripts/install_commit_msg_hook.sh`

## References

- `references/summary-and-examples.md`
