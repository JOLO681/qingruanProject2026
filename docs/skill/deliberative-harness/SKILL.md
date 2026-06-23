---
name: deliberative-harness
description: 语言无关的审议式多Agent编排框架。通过文件媒介的多角色迭代审议，对抗单一Agent的认知偏差与幻觉风险。覆盖需求澄清、架构设计、技术选型、编码实现、代码审查、Lint治理、Warning治理、问题诊断、通用执行、PDC规划驱动、再审议等场景。
---

# 审议式编排框架 (Deliberative Harness)

## 设计哲学

1. **文件为唯一沟通媒介** — Agent 间不直接传递内容，所有产出、审议意见、质询问题均通过文件交换。杜绝角色兼任，每个 Agent 只扮演单一角色。
2. **内置审议/质询机制** — 每个环节都配备独立的审议 Agent，多轮迭代直至达成一致。
3. **主 Agent 仅做编排路由** — 主 Agent（你）只读取文件路径状态、决定路由、发起下一轮，**绝不参与任何环节的内容产出或判断**。
4. **语言无关** — 框架不绑定任何特定编程语言。Agent 指令中对语言特性的引用均为示例性质，实际使用时 Agent 应根据项目实际使用的语言/技术栈自适应。

## 技能一览

| 技能 | 做什么 | 审议模式 |
|------|--------|----------|
| **前置准备** [deliberation-prep](./deliberation-prep/SKILL.md) | 生成时间戳、写入用户指令原文，供所有审议式流程复用 | 无，纯前置准备 |
| **需求设计** [requirement-design](./requirement-design/SKILL.md) | 将模糊需求澄清为清晰、完整的需求文档 | 澄清者 ↔ 验证者 |
| **架构设计** [architecture-design](./architecture-design/SKILL.md) | 完成架构级 OOD 设计，聚焦职责划分与抽象层次 | 设计者 ↔ 验证者 |
| **技术设计** [technical-design](./technical-design/SKILL.md) | 确定技术选型和方案决策，衔接架构与编码 | 设计者 ↔ 验证者 |
| **编码实现** [deliberative-implementation](./deliberative-implementation/SKILL.md) | 将任务逐步实现为可运行代码 | 计划↔设计↔编码↔验证，四阶段管线，每段内嵌审议 |
| **审议式执行** [deliberative-execution](./deliberative-execution/SKILL.md) | 通过「执行-审查」审议循环完成任意用户任务 | 执行者 ↔ 审查者 |
| **代码审查** [code-review](./code-review/SKILL.md) | 与用户协作进行渐进式代码审查 | 人机协作，人定范围，审查者执行 |
| **Lint 治理** [lint-governance](./lint-governance/SKILL.md) | 对代码库进行渐进式 lint 治理 | 检查者 → 计划者 → 执行者 |
| **Warning 治理** [warning-governance](./warning-governance/SKILL.md) | 对代码库进行渐进式 warning 治理 | 检查者 → 计划者 → 执行者 |
| **问题诊断** [problem-diagnosis](./problem-diagnosis/SKILL.md) | 定位问题根因，建立完整证据链 | 诊断者 ↔ 质询者 |
| **通用 PDC** [generic-pdc](./generic-pdc/SKILL.md) | 以渐进式规划驱动任意任务逐步推进，产出形式不限 | Planner ↔ Plan Reviewer、Doer ↔ Do Reviewer、Checker ↔ Check Reviewer |
| **再审议框架** [redeliberation](./redeliberation/SKILL.md) | 对任意审议式技能的产出进行 A-B 迭代质量审查，直到通过或达到最大迭代次数 | 组件A执行审议式技能 ↔ 组件B质量审查 |

## 典型组合路径

- **从零构建**：需求设计 → 架构设计 → 技术设计 → 编码实现
- **诊断修复**：问题诊断 → 需求设计 → 编码实现
- **审查迭代**：代码审查 → 需求设计 → 编码实现
- **质量治理**：Lint 治理 / Warning 治理，独立运行
- **通用任务**：审议式执行 / 通用 PDC，独立运行，不限产出物形态

## 使用方式

在对话中描述任务，主 Agent 会根据任务类型自动选择对应的子技能。也可以明确指定使用某个技能：

- "帮我做架构设计" → architecture-design
- "审查这段代码" → code-review
- "诊断这个 bug" → problem-diagnosis
- "用再审议框架重新审查" → redeliberation
- "执行这个任务" → deliberative-execution

## Agent 工具约定

本框架使用 Claude Code 的 Agent 工具启动子 Agent（`subagent_type: "general-purpose"`）。所有子 Agent 指令文档均在对应技能目录下，启动时让 Agent 自行阅读指令文件，不要将指令内容复制到 prompt 中。
