---
name: deliberative-implementation
description: "采用审议式「计划-设计-编码-验证」管线框架，将任务逐步实现为可运行代码。语言无关。"
---

## 概述

```
Planner ↔ Plan Reviewer   (审议)
Designer ↔ Design Reviewer (审议)
Coder    ↔ Code Reviewer   (审议)
Verifier ↔ Test Reviewer   (审议)
Runner
```

主Agent仅负责调度子Agent执行各步骤，不参与任何环节的执行。

输入：整个任务的完整描述 → 输出：源码 + 单元测试。每个生产环节最多 12 轮审议式审查。

## 硬性约束

- 步骤 A–J 每一步必须独立启动 agent，严禁将多个步骤合并到一次调用
- 生产者与审查员必须在不同的 agent 中执行，不得角色兼任
- agent 间只传文件路径，不传内容
- 主Agent仅做路由，禁止读取子Agent产出文件或参与任何环节执行
- 整个管线在与 workdir 同名的分支上运行，初始化时创建，运行期间不得切换

子agent指令（启动时让agent自行阅读）：

- [planner](./planner.md) · [plan_reviewer](./plan_reviewer.md)
- [designer](./designer.md) · [design_reviewer](./design_reviewer.md)
- [coder](./coder.md) · [code_reviewer](./code_reviewer.md)
- [verifier](./verifier.md) · [test_reviewer](./test_reviewer.md) · [runner](./runner.md)

## 参数

| 参数 | 必填 | 说明 |
|------|------|------|
| `workdir` | 是 | 工作目录绝对路径，命名：`implements/{YYYYMMDDHHMM}_{简要描述}/` |
| `requirement` | 是 | 整个任务的完整描述，初始化时写入 `{workdir}/requirement.md` |
| `project_root` | 是 | 项目根目录绝对路径 |
| `max_rounds` | 否 | 最大任务轮次，默认 30 |

## 文件约定

| 文件 | 维护者 |
|------|--------|
| `{workdir}/requirement.md` | 主Agent，初始化时写入 |
| `{workdir}/plan.md` | Planner |
| `{workdir}/task_v{N}.md` | Planner |
| `{workdir}/plan_review_v{N}_r{R}.md` | Plan Reviewer |
| `{workdir}/detail_v{N}.md` | Designer |
| `{workdir}/design_review_v{N}_r{R}.md` | Design Reviewer |
| `{workdir}/code_v{N}.md` | Coder |
| `{workdir}/code_review_v{N}_r{R}.md` | Code Reviewer |
| `{workdir}/test_v{N}.md` | Verifier |
| `{workdir}/test_review_v{N}_r{R}.md` | Test Reviewer |
| `{workdir}/verify_v{N}.md` | 主Agent |

源码和测试直接写入 `{project_root}/` 目录树。

## 审议循环规则

步骤 A-B、C-D、E-F、G-H 均遵循相同规则：

1. 生产者写出产出文件，返回 `{TOKEN_WRITTEN}:{路径}`
2. 审查员审查，返回 `APPROVED` 或 `REJECTED`
3. `APPROVED` → 进入下一环节
4. `REJECTED` 且 `R < 12` → `R++`，回到生产者修订
5. `REJECTED` 且 `R ≥ 12` → plan.md 追加 BLOCKED 记录，`N++`，回到步骤 A

## 编排流程

### 1. 初始化

创建 `{workdir}/`，将 `{requirement}` 写入 `{workdir}/requirement.md`。`N = 1`。以 workdir 路径最后一段为分支名，执行 `git checkout -b {branch}`。

### 2. 管线循环（最多 max_rounds 轮）

**步骤 A — Planner** → **步骤 B — Plan Reviewer**（`PR = 1`，按审议循环规则执行）

Planner prompt（`subagent_type: "general-purpose"`）：
```
请先阅读 ./planner.md 获取指令，然后：
整个任务的完整描述：{workdir}/requirement.md
计划文件：{workdir}/plan.md
任务输出：{workdir}/task_v{N}.md
项目根目录：{project_root}
{PR > 1 时追加：审查文件：{workdir}/plan_review_v{N}_r{PR-1}.md}
{N > 1 时追加：上一轮最终产出：{workdir}/detail_v{N-1}.md, {workdir}/code_v{N-1}.md, {workdir}/test_v{N-1}.md, {workdir}/verify_v{N-1}.md}
```
返回 `TASK_ASSIGNED:{路径}` 继续，或 `ALL_DONE:{路径}` 跳到步骤 3。

**步骤 C — Designer** → **步骤 D — Design Reviewer**（`DR = 1`）
**步骤 E — Coder** → **步骤 F — Code Reviewer**（`CR = 1`）
**步骤 G — Verifier** → **步骤 H — Test Reviewer**（`TR = 1`）
**步骤 I — Runner** — 执行测试、写验证报告并提交
**步骤 J — 轮次推进** — `N++`，回到步骤 A

### 3. 返回结果

- 正常：`实现已完成，计划文件：{workdir}/plan.md，共完成 {已完成任务数} 个任务，分支：{branch}`
- 达上限：`达到最大轮次限制，计划文件：{workdir}/plan.md，最新验证报告：{workdir}/verify_v{N-1}.md`

仅返回文件路径和统计信息，不输出内容到对话。
