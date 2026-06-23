---
name: deliberative-technical-design
description: "采用「设计-验证」审议框架完成技术方案设计。语言无关。"
---

## 框架概述

本技能实现一个「设计-验证」审议循环：两个子agent以文件为唯一沟通媒介，交替运行，审议迭代，直至技术方案的所有技术选型和方案决策都已确定。主Agent仅负责编排，禁止读取子Agent产出文件，仅凭返回状态标记路由。

技术方案是衔接架构设计和编码实现的桥梁——比架构设计更具体（落实到库和技术路径级别），但比代码更抽象（不涉及具体实现细节）。框架不预设技术方案应包含哪些具体内容——由设计agent根据用户输入的实际情况自行判断需要明确哪些技术事项。

子agent完整指令文档：

[designer](./designer.md)：技术方案设计agent的角色定义、工作流程与输出规范

[verifier](./verifier.md)：技术方案验证agent的审查维度、报告格式与通过/驳回判定标准

## 调用参数

- **`workdir`**（必填）— 工作目录的绝对路径
- **`requirement`**（必填）— 完整需求描述，初始化时写入 `{workdir}/requirement.md`

### workdir 命名规范

运行 `date +%Y%m%d%H%M` 得到 `{YYYYMMDDHHMM}`。

workdir 应位于工作区的 `designs-tech/` 目录下，命名格式为 `designs-tech/{YYYYMMDDHHMM}_{简要描述}/`。

## 文件约定

| 文件 | 维护者 |
|------|--------|
| `{workdir}/requirement.md` | 主Agent，初始化时写入 |
| `{workdir}/tech_v{N}.md`（N 从1开始递增） | designer |
| `{workdir}/review_v{N}.md` | verifier |

## 编排流程

### 1. 初始化

- 创建 `{workdir}/` 目录（如不存在）
- 将 `{requirement}` 写入 `{workdir}/requirement.md`
- 初始化轮次计数器 `N = 1`

### 2. 审议循环（最多 5 轮）

**步骤 A — 启动技术方案设计agent**

使用 Agent 工具（`subagent_type: "general-purpose"`）：
```
请先阅读文件 ./designer.md 获取完整工作指令，然后按要求完成以下任务：

任务描述：{workdir}/requirement.md
技术方案输出文件：{workdir}/tech_v{N}.md
{若 N > 1，追加：上一轮审查文件：{workdir}/review_v{N-1}.md}
```
等待返回 `TECH_DESIGN_WRITTEN:路径`。

**步骤 B — 启动验证agent**
```
请先阅读文件 ./verifier.md 获取完整工作指令，然后按要求完成以下任务：

任务描述：{workdir}/requirement.md
待审查技术方案文件：{workdir}/tech_v{N}.md
审查输出文件：{workdir}/review_v{N}.md
```
等待返回 `APPROVED:路径` 或 `REJECTED:路径`。

**步骤 C — 判断终止**

- `APPROVED` → 循环结束
- `REJECTED` → `N++`，回到步骤 A
- N 已达 5 → 循环结束

### 3. 向用户返回结果

- 达成一致：`技术方案设计已完成，最终方案：{workdir}/tech_v{N}.md`
- 未达成一致：提取分歧点，附上最终路径

**不要**将内容输出到对话中，仅返回文件路径。
