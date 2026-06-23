---
name: deliberative-requirement-design
description: "采用「澄清-验证」审议框架完成需求设计。语言无关。"
---

## 框架概述

本技能实现一个「澄清-验证」审议循环：两个子agent以文件为唯一沟通媒介，交替运行，审议迭代，直至将用户的模糊需求澄清为清晰、完整、准确的需求文档。主Agent仅负责编排，禁止读取子Agent产出文件，仅凭返回状态标记路由。

需求设计是整个设计管线的起点——它不产出结构化的需求规格说明书，而是将用户可能模糊、零散、不完整的描述，加工成一份**清晰、完整、准确**的叙述性文档，使下游的架构设计者和技术设计者能准确理解"要做什么"。

子agent完整指令文档（启动时让agent自行阅读，不要将内容复制到prompt中）：

[designer](./designer.md)：需求澄清agent的角色定义、工作流程与输出规范

[verifier](./verifier.md)：需求验证agent的审查维度、报告格式与通过/驳回判定标准

## 调用参数

- **`workdir`**（必填）— 工作目录的绝对路径
- **`requirement`**（必填）— 用户的原始需求描述，初始化时写入 `{workdir}/requirement.md`

### workdir 命名规范

运行 `date +%Y%m%d%H%M` 得到 `{YYYYMMDDHHMM}`。

workdir 应位于工作区的 `requirements/` 目录下，命名格式为 `requirements/{YYYYMMDDHHMM}_{简要描述}/`。

## 文件约定

| 文件 | 维护者 |
|------|--------|
| `{workdir}/requirement.md` | 主Agent，初始化时写入 |
| `{workdir}/req_v{N}.md`（N 从1开始递增） | designer |
| `{workdir}/review_v{N}.md` | verifier |

## 编排流程

### 1. 初始化

- 创建 `{workdir}/` 目录（如不存在）
- 将 `{requirement}` 写入 `{workdir}/requirement.md`
- 初始化轮次计数器 `N = 1`

### 2. 审议循环（最多 5 轮）

每轮依次执行步骤 A → B → C：

**步骤 A — 启动需求澄清agent**

使用 Agent 工具（`subagent_type: "general-purpose"`）启动：
```
请先阅读文件 ./designer.md 获取完整工作指令，然后按要求完成以下任务：

用户原始需求：{workdir}/requirement.md
需求文档输出文件：{workdir}/req_v{N}.md
{若 N > 1，追加：上一轮审查文件：{workdir}/review_v{N-1}.md}
```
等待返回 `REQ_WRITTEN:路径`。

**步骤 B — 启动验证agent**
```
请先阅读文件 ./verifier.md 获取完整工作指令，然后按要求完成以下任务：

用户原始需求：{workdir}/requirement.md
待审查需求文件：{workdir}/req_v{N}.md
审查输出文件：{workdir}/review_v{N}.md
```
等待返回 `APPROVED:路径` 或 `REJECTED:路径`。

**步骤 C — 判断终止**

- 返回 `APPROVED` → 循环结束
- 返回 `REJECTED` → `N++`，回到步骤 A
- 若 N 已达 5 → 循环结束

### 3. 向用户返回结果

- 达成一致：`需求设计已完成，最终需求文档：{workdir}/req_v{N}.md`
- 未达成一致：提取分歧点，附上最终需求文档路径和审查路径

**不要**将内容输出到对话中，仅返回文件路径。
