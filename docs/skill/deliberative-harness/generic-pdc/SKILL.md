---
name: deliberative-generic-pdc
description: "审议式通用 PDC 循环技能，以 Plan-Do-Check 渐进式规划驱动任意任务逐步推进。语言无关。"
---

## 概述

```
Planner ↔ Plan Reviewer    (审议)
Doer     ↔ Do Reviewer     (审议)
Checker  ↔ Check Reviewer  (审议)
```

主Agent仅负责调度子Agent执行各步骤，不参与任何环节的执行。

输入：完整任务描述 → 输出：任务产出（形式不限）。每个环节最多 12 轮审议式审查。

## 硬性约束

- 步骤 A–H 每一步必须独立启动 agent，严禁将多个步骤合并到一次调用
- 生产者与审查员必须在不同的 agent 中执行，不得角色兼任
- agent 间只传文件路径，不传内容
- 主Agent仅做路由、N++ 轮次推进和步骤中规定的 git 提交，禁止读取子Agent产出文件
- 整个管线在与 workdir 同名的分支上运行，初始化时创建，运行期间不得切换

子agent指令（启动时让agent自行阅读）：

- [planner](./planner.md) · [plan_reviewer](./plan_reviewer.md)
- [doer](./doer.md) · [do_reviewer](./do_reviewer.md)
- [checker](./checker.md) · [check_reviewer](./check_reviewer.md)

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| `workdir` | 是 | 工作目录绝对路径，命名：`pdc/{YYYYMMDDHHMM}_{简要描述}/` |
| `task` | 是 | 完整任务描述，初始化时写入 `{workdir}/task.md` |
| `max_rounds` | 否 | 最大 PDC 轮次，默认 30 |

## 文件约定

| 文件 | 维护者 |
|------|--------|
| `{workdir}/task.md` | 主Agent，初始化时写入 |
| `{workdir}/plan.md` | Planner |
| `{workdir}/task_v{N}.md` | Planner |
| `{workdir}/plan_review_v{N}_r{R}.md` | Plan Reviewer |
| `{workdir}/do_v{N}.md` | Doer |
| `{workdir}/do_review_v{N}_r{R}.md` | Do Reviewer |
| `{workdir}/check_v{N}.md` | Checker |
| `{workdir}/check_review_v{N}_r{R}.md` | Check Reviewer |

workdir 中的其他文件均为产出，由 Doer 创建和修改。

## 审议循环规则

步骤 A-B、C-D、E-F 均遵循相同规则：

1. 生产者写出产出文件，返回 `{TOKEN_WRITTEN}:{路径}`
2. 审查员审查，返回 `APPROVED` 或 `REJECTED`
3. `APPROVED` → 进入下一环节
4. `REJECTED` 且 `R < 12` → `R++`，回到生产者修订
5. `REJECTED` 且 `R ≥ 12` → `N++`，回到步骤 A

## 编排流程

### 1. 初始化

创建 `{workdir}/`，将 `{task}` 写入 `{workdir}/task.md`。`N = 1`。以 workdir 路径最后一段为分支名，执行 `git checkout -b {branch}`。

### 2. PDC 循环（最多 max_rounds 轮）

**步骤 A — Planner** → **步骤 B — Plan Reviewer** `PR = 1`
**步骤 C — Doer** → **步骤 D — Do Reviewer** `DR = 1`
**步骤 E — Checker** → **步骤 F — Check Reviewer** `CR = 1`
**步骤 G — 提交** Checker 审议通过后，执行 `git add -A && git commit -m "v{N} done"`
**步骤 H — 轮次推进** `N++`，回到步骤 A

### 3. 返回结果

- 正常：`任务已完成，计划文件：{workdir}/plan.md，共完成 {已完成任务数} 个任务，分支：{branch}`
- 达上限：`达到最大轮次限制，计划文件：{workdir}/plan.md`

仅返回文件路径和统计信息，不输出内容到对话。
