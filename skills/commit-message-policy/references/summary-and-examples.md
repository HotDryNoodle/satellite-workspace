# Commit Message Policy References

## 规则展开

- 第一行必须匹配 `<type>(<scope>): <summary>`
- `type` 只能使用 `feat|fix|refactor|docs|test|build|ci|chore|perf`
- `scope` 可选；若存在，只能使用小写字母、数字、逗号、连字符
- `summary` 长度限制为 `1..72`
- header 之后必须按顺序包含 `Goal:`、`Changes:`、`version-check:`
- 每个 section 都必须存在；没有内容时必须显式写 `n/a`
- section 标签固定使用英文关键字加半角冒号
- section 内容建议使用中文
- 每个 section 至少保留一行非空内容

## 推荐模板

```text
<type>(<scope>): <summary>

Goal:
- ...

Changes:
- ...

version-check:
- ...
```

## 通过示例

```text
chore(lock,sdk): 将 SDK 升至 08b8979 并同步 consumer wrap

Goal:
- 父仓库集成锁与 task-manager、mission-planer 的 SDK wrap revision 保持一致。

Changes:
- 更新 sdk、task-manager、plugins/* submodule gitlinks
- 再生 VERSIONS.lock
- 同步各 consumer satellite-plugin-sdk.wrap revision

version-check:
- ./scripts/update-lock.sh
- SATELLITE_STRICT_VERSIONS=1 ./scripts/check-versions.sh --strict
- ./scripts/smoke-integration.sh
```

## 不通过示例

```text
unknown(scope): this should fail
```

原因：`type` 不在白名单。

```text
fix(scope) missing colon
```

原因：缺少 `: ` 分隔符。

```text
docs(commit-policy): 只写标题
```

原因：缺少必填 section。

```text
trace(commit-policy): 治理类提交
```

原因：`trace` 不在 type 白名单（治理类变更请使用 `chore`）。
