# 详细设计方案审查报告（v2 验证轮）

## 审查结果

**APPROVED**

## 审查范围

本审查聚焦三个核心任务：
1. 验证 `a_v2_iteration_requirement.md` 中列出的 8 个质量问题是否已全部修复
2. 确认修改没有引入新的问题或与 SRS（`1_requirements_analysis_v1.md`）产生新的不一致
3. 从设计文档内部一致性和可实现性角度做补充审查

## 逐维度审查

### 1. 路由守卫访问控制漏洞修复验证

**[通过]** 原问题：`publicRoutes` 包含 `'consultation'`，导致 `#/consultation/doctor/:id`（需认证）被公开路由放行。

修复确认：
- `publicRoutes` 已从 `['home', 'news', 'consultation', 'login']` 修改为 `['home', 'news', 'login']`（第316行），`consultation` 已移除。
- 新增 `routeAuthRules` 细粒度路由权限表（第324-331行），`consultation` 主路由 `defaultPublic: true`（医生列表公开），子路由 `{ pattern: 'doctor', authRequired: true }`（对话需认证）。
- 路由守卫函数新增步骤1.5（第343-363行）实现子路由匹配逻辑：无子路径时使用 `defaultPublic`；子路径匹配 `subRule` 时按 `authRequired` 决定是否放行；未匹配任何子规则时默认要求认证（安全默认拒绝），正确实现了纵深防御。
- 路由守卫逻辑完整覆盖了 Token 检查、管理员强制改密拦截、admin 角色校验等所有原有安全层级，无回归。

### 2. Dify工作流与SQLite交互架构断裂修复验证

**[通过]** 原问题：punch-analysis 和 health-article-generator 工作流假定 Dify 可直接访问本地 SQLite，但实际二者网络不可达；同时 inputs 定义缺少预查询数据字段。

修复确认：
- 第3.6节 Express 代理层参数映射表新增 `punch_records → inputs.punch_records` 和 `user_health_data → inputs.user_health_data` 两条映射规则（第1975-1976行），并附带"预查询数据注入说明"段落（第1978-1980行），明确 Express 代理层在调用 Dify 前预先查询数据库并注入 inputs。
- 第5.2.3节 health-article-generator 输入变量表新增 `user_health_data` 字段（第3301行），字段说明明确"Dify工作流不自行查询数据库，直接使用此预查询数据"。
- 第5.2.4节 punch-analysis 输入变量表新增 `punch_records` 字段（第3332行），字段说明同样明确预查询语义。
- 第5.3.3节 health-article-generator 工作流编排图中，"查询用户健康数据节点"已改为"接收预查询用户健康数据节点"（第3515行），节点说明同步更新（第3519行）。
- 第5.3.4节 punch-analysis 工作流编排图中，"打卡数据查询节点"已改为"接收预查询打卡数据节点"（第3528行），节点说明同步更新（第3531行）。
- 数据通路完整闭环：Express 预查询 → inputs 注入 → Dify 工作流接收 → LLM 分析 → 结果返回，无断裂点。

### 3. JS逻辑流程图覆盖率修复验证

**[通过]** 原问题：第4.3节仅覆盖 5/12 页面，缺失 index.html、profile.html、punch.html、health-advice.html、admin.html、login.html、change-password.html 共7个页面的 JS 逻辑流程图。

修复确认：
- 第4.3节现已包含全部12个页面的完整 mermaid flowchart：
  - home.html（第2574行起）、consultation.html（第2588行起）、risk.html（第2611行起）、life-plan.html（第2634行起）、news.html（第2651行起）
  - **新增**：index.html（第2672行起，含 hashchange 监听、routeGuard 调用、postMessage 消息路由、JWT 拦截器、Tab 切换、FAB 弹窗等全部跨模块核心逻辑）
  - **新增**：profile.html（第2713行起）、punch.html（第2736行起）、health-advice.html（第2760行起）
  - **新增**：admin.html（第2783行起，含对话视图和日志列表视图双路径）、login.html（第2812行起）
  - **新增**：change-password.html（第2838行起，含强制改密完整流程）
- index.html 流程图的补充尤为关键——该页面作为 SPA 主框架核心引擎，其流程图覆盖了 hashchange 事件监听、routeGuard 路由守卫、postMessage 消息路由分发、JWT fetch 拦截器（请求拦截+响应拦截）、Tab 切换同步、FAB 弹窗控制等全部跨模块逻辑，不再缺失关键流程。
- 覆盖率：12/12（100%），所有缺失页面已补齐。

### 4. 状态管理方案缺失修复验证

**[通过]** 原问题：状态管理方案表（第4.2节）缺少 profile.html、punch.html、health-advice.html 的完整状态规划；admin.html 和 change-password.html 覆盖不完整；news.html 分页状态使用内存变量导致页面切换后丢失。

修复确认：
- **新增行**：profile.html（第2557-2558行）：用户信息（内存+API）、功能入口菜单显隐状态（sessionStorage，基于 role）。
- **新增行**：punch.html（第2559-2560行）：列表筛选条件（sessionStorage）、分页状态（sessionStorage）、列表数据（内存+API）、分析统计数据（内存+API）。
- **新增行**：health-advice.html（第2561-2562行）：列表分页状态（sessionStorage）、当前展开卡片ID（sessionStorage）、列表数据（内存+API）。
- **完善**：admin.html（第2564-2566行）补充了提交中防重复标志（内存）、SSE 流连接状态（内存）、视图状态（sessionStorage）、日志列表分页状态（sessionStorage）。
- **完善**：change-password.html（第2567-2568行）补充了 must_change_password 标志（localStorage 读取）、提交中防重复标志（内存）。
- **修正**：news.html 分页状态从内存变量改为 sessionStorage 持久化（第2555行），页面切换后分页位置不丢失。
- consultation.html 补充了当前视图状态（sessionStorage）、SSE 流连接状态（内存）（第2549-2550行）。
- index.html 补充了 `must_change_password` 标志（localStorage）（第2544行）。
- 所有12个页面均有完整的状态管理方案条目，存储介质选择（localStorage/sessionStorage/内存）与数据生命周期匹配合理。

### 5. Tailwind rounded-lg 圆角值修正验证

**[通过]** 原问题：设计将 `rounded-lg` 注释为"对应12px圆角"，但 Tailwind CSS v3 中 `rounded-lg` 默认值为 0.5rem（8px），12px 对应 `rounded-xl`（0.75rem）。同时 CSS 变量 `--radius-button: 12px` 与组件样式中使用的 `rounded-lg`（实际渲染8px）不一致。

修复确认：
- 组件样式规范表（第4.5.2节，第3000-3014行）中所有需要12px圆角的组件（卡片、主按钮、次按钮、危险按钮、消息气泡-AI、消息气泡-用户、Toast提示）已从 `rounded-lg` 统一改为 `rounded-xl`。
- CSS变量定义（第4.5.1节，第2976-2979行）保持 `--radius-md: 8px`、`--radius-lg: 12px`、`--radius-button: 12px`，与组件样式表中的 `rounded-xl`（12px）语义一致。
- 新增"Tailwind圆角映射说明"段落（第3016行），明确标注 `rounded-lg` = 8px、`rounded-xl` = 12px 的映射关系，并说明设计系统选择 `rounded-xl` 作为默认组件圆角值。
- 骨架屏中 `rounded-lg` 的使用（第3026行，20x20 图片占位）属于8px小圆角的合理场景，不构成不一致。
- 无遗留的 `rounded-button` 自定义类（该问题已在上一轮修复中解决）。

### 6. CORS配置修复验证

**[通过]** 原问题：Nginx CORS 配置仍使用 `$http_origin` 变量回显任意 Origin，仅以注释方式提示风险，未给出生产环境安全替代方案。

修复确认：
- 第6.1.1节 Nginx 配置中 CORS 配置块（第3683-3717行）已重构为结构化3方案：
  - **方案A（生产环境推荐）**：同源部署时整体移除 CORS 块，附说明（CORS 为冗余且暴露不必要的响应头信息面）。
  - **方案B（生产环境跨域）**：将 `$http_origin` 替换为固定白名单域名字符串，单域名用固定字符串，多域名用 map 块白名单校验。
  - **方案C（开发环境）**：保留 `$http_origin` 仅限本地调试，附安全风险警告并严禁用于生产环境。
  - **附录**：提供完整的 Nginx map 白名单多域名方案代码示例（第3707-3717行），含 map 块定义、location 块引用和原理说明。
- 当前配置默认使用方案C并附有"生产部署前必须切换至方案A或方案B"的醒目提示。
- 方案完整可执行，不再仅以注释提示风险而无实际行动方案。

### 7. Keepalived Nginx健康检查修复验证

**[通过]** 原问题：Keepalived 仅配置 VRRP 心跳，缺少 `vrrp_script` 和 `track_script` 来监控 Nginx 进程。若 Nginx 崩溃但服务器仍运行，VIP 不会漂移。

修复确认：
- 服务器2（MASTER）Keepalived 配置（第3946-3969行）新增 `vrrp_script chk_nginx` 块：通过 `killall -0 nginx` 检查 Nginx 进程存在性，检测间隔2秒，失败权重-20，连续3次失败判定故障，连续2次成功判定恢复。
- 服务器3（BACKUP）Keepalived 配置（第3977-4000行）同样新增完整的 `vrrp_script chk_nginx` 和 `track_script` 块。
- 故障转移流程描述已更新（第4004行）：MASTER Nginx 崩溃 → chk_nginx 连续3次检测失败（6秒）→ priority 降至 80 → BACKUP priority 90 > 80 → VIP 自动漂移 → Nginx 恢复后自动夺回。
- 健康检查脚本命令、检测参数、权重漂移值设置合理，形成完整的 Nginx 进程级故障检测与 VIP 漂移闭环。

### 8. Express server.js 启动错误处理修复验证

**[通过]** 原问题：`initDatabase()` 调用未被 try-catch 包裹，数据库初始化失败时 Express 仍会启动监听端口但不可用。

修复确认：
- server.js（第3812-3819行）已将 `initDatabase()` 调用包裹在 try-catch 块中。
- 成功路径：`initDatabase()` 成功 → 输出 `[Server] 数据库初始化成功` → 继续执行 `app.listen()`。
- 失败路径：`initDatabase()` 抛出异常 → 输出 `[Server] 数据库初始化失败，进程终止:` + 错误消息 → 输出完整堆栈 `error.stack` → `process.exit(1)` 以非零退出码终止进程。
- `process.exit(1)` 非零退出码便于 systemd/Docker 等进程管理器检测启动失败并触发告警或自动重启。
- app.listen() 仅在 initDatabase() 成功后才执行，避免了"数据库不可用但端口已监听"的半失效状态。

## 与SRS一致性检查

对照 SRS 文档（`1_requirements_analysis_v1.md` v7）做以下关键一致性检查：

- **技术栈**：SRS v7（第16.14节）已将前端技术栈从 Vue3+Vite 更新为原生 HTML/CSS/JavaScript + CDN 引入，与详细设计文档一致。
- **架构模式**：SRS 定义的 SPA + iframe 子页面架构、postMessage 通信机制、hash 路由方案，均在详细设计中有完整展开。
- **数据库**：SRS 定义的10张表结构（users/doctor_information/articles/diabetes_types/article_collections/user_risk_info/life_plans/life_advice/punch_in/admin_logs）与详细设计 DDL 完全一致，字段、类型、约束无差异。
- **API 端点**：SRS 定义的14组端点（auth/user/risk/doctors/chat/plan/punch/articles/diabetes-types/assistant/admin/dify/upload）在详细设计中均有对应的完整 JSON Schema 定义。
- **Dify 工作流**：SRS 定义的7个 Dify 应用（diabetes-risk-prediction/life-plan-generator/health-article-generator/punch-analysis/diabetes-assistant-agent/admin-manager-agent/doctor-chat-{id}）在详细设计中均有完整的系统提示词、输入变量、输出结构和编排流程图。
- **部署架构**：SRS 定义的3台服务器角色分工、Nginx 反向代理+负载均衡、Keepalived 主备模式、SQLite 单实例限制，在详细设计中均有对应的完整配置文件和说明。
- **安全机制**：SRS 定义的 JWT 鉴权流程、bcrypt 密码哈希、双认证模式（JWT + API Key）、路由守卫、CSRF/XSS/SQL注入防护，在详细设计中均有完整实现方案。

**无新引入的SRS不一致问题。**

## 新问题检测

逐项检查本轮8个修复是否引入新的设计缺陷或内部矛盾：

- **路由守卫修复**：`routeAuthRules` 机制对 consultation 路由的子路由粒度检查逻辑正确。无子路由时使用 `defaultPublic`，有子路由时按 subRule 匹配（安全默认拒绝），与其他路由（publicRoutes 直接放行、其余要求认证）形成一致的安全层级。无新引入问题。
- **Dify 预查询修复**：Express 代理层的预查询职责已明确描述，punch-analysis 和 health-article-generator 工作流的 inputs 定义和编排流程图已同步更新。预查询逻辑与第6.3节/第6.7节的 POST 端点处理流程（AI 内容生成持久化路径）形成互补而不重叠。无新引入问题。
- **流程图补充**：新增的7个页面流程图与已有5个页面流程图风格一致（均使用 mermaid flowchart），决策节点和 API 调用标注清晰。index.html 流程图覆盖了主框架的全部核心逻辑（hashchange、routeGuard、postMessage路由、JWT拦截器、Tab切换、FAB弹窗），与原4.1/4.2/4.4/4.7节描述一致。无新引入问题。
- **状态管理补充**：新增和修正的状态管理条目存储介质选择合理（跨会话用 localStorage、标签页生命周期用 sessionStorage、页面生命周期用内存），与各页面 JS 流程图中的数据读写操作一致。news.html 分页状态改为 sessionStorage 后与流程图中"从 sessionStorage 读取筛选条件"的步骤匹配。无新引入问题。
- **圆角值修正**：`rounded-lg → rounded-xl` 的替换覆盖了所有需12px圆角的组件，CSS 变量值与 Tailwind 工具类语义对齐。骨架屏保留 `rounded-lg`（8px）属于合理的小圆角场景。无新引入问题。
- **CORS 修复**：三种方案分层清晰，map 白名单方案的代码示例可直接用于生产配置。当前默认使用方案C（开发调试）符合实训项目的开发阶段定位。无新引入问题。
- **Keepalived 修复**：MASTER 和 BACKUP 的 vrrp_script 配置对称且参数合理（priority 差距10 + weight 降幅20 确保故障时 priority 反转）。故障转移时间（~6秒检测 + 漂移）在可接受范围内。无新引入问题。
- **Express 错误处理修复**：try-catch 包裹范围正确（仅包裹 initDatabase），不影响 app.listen 的正常异步回调结构。process.exit(1) 是 Node.js 标准实践。无新引入问题。

**本轮修复未引入新的严重或一般级别问题。**

## 轻微观察（不阻塞通过）

以下为审查过程中注意到的可改进点，不阻塞 APPROVED 判定：

1. **路由守卫 routeAuthRules 扩展性**：当前仅 consultation 路由使用了 `routeAuthRules` 细粒度控制。如果未来有其他路由需要子路由级别权限区分（如 profile 下的子页面），需按相同模式扩展。当前设计范围覆盖完整，非阻塞。

2. **Express 预查询注入的并发安全**：punch-analysis 和 health-article-generator 的预查询逻辑在并发请求场景下各自独立执行（每次请求独立查询），不存在共享状态竞争。但若未来同用户短时间内多次请求同一工作流，会产生重复的数据库查询开销——当前规模下不构成实际问题，可在实现阶段按需添加短时效缓存。

3. **Keepalived 健康检查命令的可移植性**：`killall -0 nginx` 在部分 Linux 发行版上可能需要安装 `psmisc` 包。可在部署文档中补充依赖说明。不影响设计正确性。

## 审查结论

全部8个质量问题已确认修复，修复方案逻辑正确、实现完整。修改未引入新的严重或一般级别问题，设计文档与 SRS v7 保持一致。**准予通过。**
