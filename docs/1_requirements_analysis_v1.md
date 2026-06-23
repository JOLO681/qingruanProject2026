# 糖尿病预治智能助手 —— 需求澄清文档

## 1. 项目定位与目标

本项目是2026年青软实训（东北大学软件学院）的核心实训项目，目标是构建一个面向普通人群和糖尿病患者的**一站式糖尿病预防与健康管理 Web 平台**。平台以 HTML、CSS、JavaScript 为前端技术栈，后端借助 DeepSeek 大模型和 Dify 智能体开发平台提供 AI 能力，帮助用户完成糖尿病风险自评、个性化生活方案获取、在线医师咨询、健康资讯浏览与收藏、日常打卡记录与分析等核心任务。

平台的 AI 能力架构为 **Dify → DeepSeek API**：DeepSeek 大模型作为底层的语言生成与推理引擎，所有 AI 功能（对话、方案生成、风险分析、资讯写作、Agent 工具调用）最终均由 DeepSeek 模型完成推理。Dify 平台负责工作流编排、Agent 管理、知识库检索、对话上下文管理、工具定义与调度等中间层能力，并将用户请求转发至 DeepSeek API 获取模型输出。前端不直接调用 DeepSeek API，而是通过 Dify 的对话/工作流接口间接使用 DeepSeek 的模型能力。

平台以**移动端优先**的 Web 应用形态交付，采用单页应用（SPA）架构，通过底部 Tab 栏切换各功能模块，各模块以 iframe 方式嵌入主框架。

### 1.1 iframe 架构下的跨模块通信机制

由于采用"SPA 主框架 + iframe 子页面"架构，跨模块协作需明确以下通信机制的设计原则（具体实现在架构设计阶段确定）：

- **登录态共享**：用户在主框架登录后，登录凭证（JWT Token）存储于浏览器 localStorage 或 sessionStorage。各 iframe 子页面读取同一存储键获取 Token，在 API 请求中通过 Authorization 请求头携带。主框架与 iframe 之间也可通过 `postMessage` 传递 Token 以保证同步更新。
- **FAB 悬浮按钮的渲染层级**：AI 智能助手的全局悬浮按钮在主框架层渲染（而非任一 iframe 内部），通过 CSS `z-index` 确保始终位于所有 iframe 之上。点击后弹出的对话窗口同样在主框架层渲染，以遮罩层覆盖当前页面内容。
- **AI 助手触发跨模块操作**：当用户在 AI 助手对话中触发需要导航到特定模块的操作（如"帮我生成生活方案"），AI 助手通过 `postMessage` 向主框架发送导航指令（含目标 Tab 标识和可选参数），主框架接收后切换底部 Tab 并传递参数给对应 iframe。
- **iframe 间数据依赖**：模块间需要传递数据时（如风险预测结果传递至生活方案模块），优先通过主框架中转——iframe A 通过 `postMessage` 发送数据至主框架，主框架缓存数据后转发给 iframe B。备选方案包括 URL 查询参数传递或共享 localStorage（需注意同源策略约束，所有 iframe 页面需部署在同一域名下）。

**postMessage 消息协议规范**：主框架与 iframe 子页面之间、iframe 子页面之间的所有跨模块通信须遵循以下消息格式约定。每条 `postMessage` 消息为一个 JSON 对象，包含 `type`（消息类型）和 `payload`（消息载荷）两个顶层字段。消息接收方在处理前必须校验 `event.origin`，仅接受来自同一域名（同源）的消息，拒绝并丢弃非同源消息。系统至少定义以下三种核心消息类型：

| 消息类型（type） | 方向 | 用途 | payload 字段 |
|----------------|------|------|-------------|
| `AUTH_SYNC` | 主框架 → 所有 iframe | 登录/登出事件广播，通知各 iframe 同步更新登录状态 | `{ token: string \| null, role: string \| null }`（登录时含 Token 和角色，登出时均为 null） |
| `NAVIGATE` | AI 助手 → 主框架 | AI 助手触发跨模块导航（如"帮我生成生活方案"） | `{ tab: string, params?: object }`（tab 为目标 Tab 标识，params 为传递给目标 iframe 的可选参数） |
| `DATA_TRANSFER` | iframe → 主框架 → iframe | 模块间数据传递（如风险预测结果传递至生活方案模块） | `{ source: string, target: string, data: object }`（source 为数据来源模块标识，target 为目标模块标识，data 为传递的数据对象） |

消息格式的具体字段定义（如消息类型枚举的完整取值、payload 子字段的详细结构）在概要设计阶段补充。各 iframe 子页面在初始化时需向主框架注册消息监听器，并在页面卸载时移除监听器。此规范为基于 iframe 架构下跨模块通信必要性的推断，具体消息类型和 payload 结构可在架构设计阶段根据实际交互需求扩展。

### 1.2 前端路由结构

平台采用 Vue3 SPA 架构，使用 **Vue Router 4** 管理前端路由。

**路由方案**：采用 Vue Router 的 **history 路由模式**（`createWebHistory`）。理由：（1）Vue3 + Vite 构建的项目天然支持 history 路由，Vite 开发服务器内置 HTML5 History API 回退；（2）生产环境 Nginx 配置 `try_files $uri $uri/ /index.html` 即可解决刷新 404 问题；（3）history 路由 URL 简洁（无 `#` 符号），更符合现代 Web 应用的用户体验。URL 路径命名采用 kebab-case 风格。

**各模块路由映射**：

| 模块 | 路由路径 | 路由名称 | Vue 页面组件 |
|------|---------|---------|-------------|
| 系统首页 | `/home` | `home` | `views/HomeView.vue` |
| 医师咨询（医生列表） | `/consultation` | `consultation` | `views/ConsultationView.vue` |
| 医师咨询（对话） | `/consultation/doctor/:id` | `doctor-chat` | `views/DoctorChatView.vue` |
| 生活方案 | `/life-plan` | `life-plan` | `views/LifePlanView.vue` |
| 健康资讯（列表） | `/news` | `news` | `views/NewsView.vue` |
| 健康资讯（详情） | `/news/article/:id` | `article-detail` | `views/ArticleDetailView.vue` |
| 个人中心 | `/profile` | `profile` | `views/ProfileView.vue` |
| 糖尿病风险预测 | `/profile/risk` | `risk` | `views/RiskView.vue` |
| 打卡记录与分析 | `/profile/punch` | `punch` | `views/PunchView.vue` |
| 健康建议 | `/profile/advice` | `advice` | `views/HealthAdviceView.vue` |
| 智能管理（管理员） | `/admin` | `admin` | `views/AdminView.vue` |
| 登录/注册 | `/login` | `login` | `views/LoginView.vue` |

**路由守卫逻辑**：Vue Router 的全局 `beforeEach` 导航守卫在每次路由切换时检查目标路由的 `meta.requiresAuth` 和 `meta.requiresAdmin` 字段。若目标路由需要认证且 Pinia `authStore` 中无有效 Token，则自动重定向至 `/login?redirect={原路径}`，登录成功后通过 `router.replace(redirect)` 回跳。鉴权逻辑集中在 `router/index.ts` 导航守卫中，各页面组件无需独立校验登录态。

**Vue Router 路由配置结构**（概要设计阶段确定完整配置）：

```typescript
// router/index.ts 示意结构
const routes = [
  { path: '/home', component: () => import('@/views/HomeView.vue'), meta: { requiresAuth: false } },
  { path: '/consultation', component: () => import('@/views/ConsultationView.vue'), meta: { requiresAuth: false } },
  { path: '/consultation/doctor/:id', component: () => import('@/views/DoctorChatView.vue'), props: true, meta: { requiresAuth: true } },
  { path: '/life-plan', component: () => import('@/views/LifePlanView.vue'), meta: { requiresAuth: true } },
  { path: '/profile', component: () => import('@/views/ProfileView.vue'), meta: { requiresAuth: true },
    children: [
      { path: 'risk', component: () => import('@/views/RiskView.vue') },
      { path: 'punch', component: () => import('@/views/PunchView.vue') },
      { path: 'advice', component: () => import('@/views/HealthAdviceView.vue') },
    ]
  },
  { path: '/admin', component: () => import('@/views/AdminView.vue'), meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/login', component: () => import('@/views/LoginView.vue'), meta: { requiresAuth: false } },
  { path: '/:pathMatch(.*)*', redirect: '/home' },
]
```

以上路由结构为基于 Vue3 SPA 架构的推断，具体路由名称、页面组件命名和懒加载策略在概要设计阶段确定。

---

## 2. 用户角色

系统包含两类用户：

- **普通用户**：平台的主要服务对象。可以浏览首页科普内容、与在线医师对话咨询、填写健康信息进行糖尿病风险预测、获取个性化的饮食与运动方案、每日打卡记录生活执行情况、浏览和收藏 AI 生成的健康资讯、使用 AI 智能助手通过自然语言完成各项操作、管理个人信息与查看打卡分析。
- **管理员**：平台的运维角色。通过自然语言对话界面操作后台数据库（基于用户描述的上下文推断，管理员的核心职责是对数据库中的用户数据、文章数据、医生信息等进行查询、新增、修改和删除操作，操作历史可追溯）。

---

## 3. 功能模块概览

平台共包含以下功能模块，它们通过底部导航栏组织在一起。各模块与导航栏的归属关系将在 4.1 节中说明：

| 模块 | 面向角色 | 功能摘要 |
|------|---------|---------|
| 系统首页 | 普通用户 | 轮播 Banner、医生团队展示、健康科普文章列表、糖尿病类型科普入口 |
| 医师咨询 | 普通用户 | 与多位专科医生进行一对一 AI 对话，支持流式回复与历史记录 |
| 个人中心 | 普通用户 | 登录注册、个人信息查看与编辑、进入风险预测、查看打卡记录、管理员入口（仅管理员可见） |
| 糖尿病风险预测 | 普通用户 | 多步骤表单采集健康数据，基于《中国2型糖尿病防治指南（2020版）》评分体系输出风险等级与建议 |
| 生活方案 | 普通用户 | 获取由 AI 生成的个性化饮食方案（早/中/晚/加餐）与运动方案（早/晚/周末），支持调整与每日打卡 |
| 健康资讯 | 普通用户 | 按分类浏览 AI 生成的健康文章，查看详情，收藏与取消收藏，查看收藏列表 |
| 打卡记录与分析 | 普通用户 | 记录每日饮食与运动打卡完成情况，查看基于打卡数据的 AI 分析 |
| AI 智能助手 | 普通用户 | 自然语言对话界面，通过 Dify Agent 调用工具链完成风险预测、方案生成、信息查询、健康建议生成等操作 |
| 智能管理 | 管理员 | 自然语言操作数据库，进行增删改查，查看操作历史，涵盖打卡信息管理和健康资讯管理场景 |

---

## 4. 功能详细描述

### 4.1 系统首页

首页是用户进入平台后的第一屏。包含以下区域：

- **顶部轮播 Banner**：展示平台核心价值主张或健康宣传图，使用 Swiper 组件实现自动轮播。
- **医生团队展示区**：以卡片或列表形式展示平台上可咨询的医生（姓名、科室、职称、头像），点击可跳转至对应医生的对话界面。
- **健康科普文章区**：以列表形式展示平台中的科普文章，点击进入文章详情。
- **糖尿病类型科普入口**：展示糖尿病主要类型（1型、2型、妊娠期糖尿病及其他特殊类型），点击查看各类型的病因、表现和治疗方式的科普说明。

底部导航栏提供"首页""咨询""生活方案""资讯""我的"五个入口（基于项目任务文档推断的导航结构）。

各模块与底部导航栏的映射关系如下：

| 底部 Tab | 包含的模块 / 子页面 |
|----------|-------------------|
| 首页 | 系统首页（直接展示） |
| 咨询 | 医师咨询（直接进入医生列表/对话） |
| 生活方案 | 生活方案（方案展示、方案调整、打卡操作均在当前 Tab 内完成） |
| 资讯 | 健康资讯（资讯列表、文章详情、收藏列表均在当前 Tab 内完成） |
| 我的 | 个人中心（主页面），从中可进入：糖尿病风险预测、打卡记录与分析、健康建议（三者均为"我的"Tab 内的子页面） |

如 4.8 节所述，AI 智能助手不位于底部导航栏中，而是以全局悬浮按钮的形式提供入口，可从任意页面访问。

**验收标准**：
- 首页在 375px 宽度的移动端视口中完整展示所有区域，无横向滚动条。
- 从首页 Banner 区域到科普文章列表，用户通过自然滚动即可浏览全部内容，无需额外操作。

### 4.2 医师咨询

平台提供多位医生（每位医生被配置为特定领域的 Dify 聊天机器人，拥有独立的系统提示词、知识库和对话参数）。每位医生关联一个 Dify 聊天助手的 API Key（存储在 doctor_information 表的 chat_token 字段中，格式为 `app-XXX`，其中 `app-XXX` 为 Dify 平台生成的访问令牌。chat_token 仅在服务端 Express 代理层使用，不暴露给前端）。用户选择一位医生后进入类即时通讯的对话界面，前端调用 Express 代理端点 `/api/chat/doctor/:id`，Express 服务端读取对应医生的 chat_token 后转发请求至 Dify 对话接口。消息通过 Dify 的流式响应（SSE）逐字返回，Express 代理层将 SSE 流透传至前端，支持完整的对话历史记录查看。对话中涉及的医学推理和回答内容由 DeepSeek 大模型生成，Dify 负责对话上下文管理和知识库检索。

用户可在对话中描述自身健康状况或提出糖尿病相关的医学问题，获得专业的健康建议。需要明确的是，此处的"医师"是由 AI 驱动的虚拟角色，而非真实的在线医生。

**会话管理**：用户进入医师对话界面时默认创建新会话（不传 conversation_id），Dify 返回新会话 ID 后前端保存至 Pinia `chatStore`（同时持久化至 localStorage 作为备份）。由于平台配置多位不同科室的医生、每位医生拥有独立的 Dify 聊天助手和对话空间，Pinia store 按医生 ID 维护 `Map<doctorId, conversationId>` 映射，使得每位医生的对话上下文独立保持，切换医生后原对话上下文不丢失。历史对话列表通过 Dify 的会话列表 API 获取（系统需提供 GET /api/chat/doctor/:id/conversations 端点，Express 代理层转发至 Dify 会话列表接口），用户可从历史会话列表中选择并恢复对话。会话不设置自动过期，由用户在 UI 中手动删除。

**验收标准**：
- 平台至少配置 3 位不同科室/领域的医生，每位医生可独立进行多轮对话。
- 用户发送消息后 3 秒内开始收到流式回复（首字返回时间）。

### 4.3 个人中心与登录注册

用户首次使用需注册账号（用户名、密码）。密码长度不少于8位，需包含字母和数字，前后端均需按此规则进行校验（前端注册表单实时校验，后端注册接口参数校验）。注册时密码通过安全通道传输至服务端，由服务端使用 bcrypt 算法进行哈希存储（具体加密细节见 4.10 节），注册信息通过 Express 常规 CRUD 接口（POST /api/auth/register）写入数据库。已注册用户可登录后使用完整功能。

个人中心展示用户头像和基本信息，提供以下入口：
- 个人信息编辑（修改用户名、密码、头像等）
- 进入糖尿病风险预测页面
- 查看打卡记录与分析
- 健康建议（查看 AI 助手生成的历史健康生活建议列表）
- 管理员菜单项（仅 admin 角色可见，跳转至智能管理界面）
- 退出登录

系统需在登录后识别用户角色（普通用户 / 管理员）。角色信息来源于 users 表中的 role 字段（取值 `user` 或 `admin`）。角色判定在前端用于控制界面元素显隐（如隐藏管理员菜单项、隐藏管理类操作入口），在后端用于接口权限校验（管理员专属接口拒绝普通用户访问）。角色由管理员在后台数据库中直接设定，系统不提供前端自助变更角色的功能（基于实训项目的管理场景推断，管理员账号由项目组预置或由已有管理员创建）。

**验收标准**：
- 用户注册成功后可直接登录，登录后根据角色看到不同的可用功能入口（普通用户不可见管理入口）。
- 未登录用户访问需认证的页面时，自动跳转至登录页。

### 4.4 糖尿病风险预测

用户通过分步向导式表单完成风险预测。前端采用多步骤表单（Step Wizard）交互模式，每一步聚焦一组相关字段，进度指示器显示当前所处步骤，用户可自由前进/后退修改已填写内容（已填写数据不会因步骤切换而丢失）。流程分为以下步骤：

1. **病史状态选择**：用户选择自己的糖尿病病史状态（如：健康、糖尿病前期、已确诊），若已确诊则需进一步选择糖尿病类型。
2. **健康信息采集**：填写年龄、性别、身高、体重、腰围、收缩压、家族糖尿病史、是否妊娠（仅女性显示）等关键指标（均来自《中国2型糖尿病防治指南（2020版）》的风险评分因素）。若用户未填写腰围或收缩压，系统基于以下公式估算替代值：

   **腰围估算**（当用户未提供时）：
   - 男性：`估算腰围(cm) = 身高(cm) × 0.47`
   - 女性：`估算腰围(cm) = 身高(cm) × 0.45`
   - BMI 调整因子：若 BMI < 18.5，腰围估算值乘以 0.92；若 BMI >= 28，腰围估算值乘以 1.10；其余情况不调整。
   
   **收缩压估算**（当用户未提供时）：
   - 男性：BMI < 24 → 120 mmHg；24 ≤ BMI < 28 → 128 mmHg；BMI ≥ 28 → 138 mmHg
   - 女性：BMI < 24 → 112 mmHg；24 ≤ BMI < 28 → 122 mmHg；BMI ≥ 28 → 132 mmHg
   - 上述分档值基于《中国2型糖尿病防治指南》中不同 BMI 分层人群的平均收缩压水平设定（基于任务文档中提供的估算逻辑整理）。

3. **结果展示**：系统根据评分体系（0-51分，≥25分为高风险）输出风险等级，若为高风险则进一步分析最可能匹配的糖尿病类型，并给出个性化的预防或管理建议。

风险评分计算和结果分析由 DeepSeek 模型根据评分规则和医学知识库完成推理，Dify 工作流负责表单数据收集、评分逻辑编排和结果格式化。

**验收标准**：
- 用户可通过进度指示器在步骤间自由前进/后退，已填写数据不会因步骤切换而丢失。
- 用户完成所有步骤并提交后，10 秒内展示风险等级和对应的预防/管理建议。
- 必填项缺失时（身高、体重、年龄、性别、家族史），给出明确的字段级校验提示，不允许提交。

**表单数据跨步骤持久化**：在 Vue3 SPA 架构下，风险预测页面组件内部通过以下双重机制保证表单数据的跨步骤持久化：（1）**Pinia store**：表单数据存储在 Pinia `riskFormStore` 中，Vue 响应式系统保证步骤间切换时数据不丢失；（2）**sessionStorage 备份**：每完成一步，表单数据同时序列化为 JSON 写入 `sessionStorage` 的专用键（如 `risk_form_data`），作为 Pinia store 的持久化备份——在用户刷新页面或意外离开后返回时，从 sessionStorage 恢复数据到 Pinia store。具体策略：
- 每完成一步，表单数据写入 Pinia `riskFormStore` 并同步序列化到 `sessionStorage`。
- 每进入新步骤时，优先从 Pinia store 读取数据回填表单字段。
- 页面组件 `onMounted` 时检查 Pinia store 是否为空——若为空则尝试从 `sessionStorage` 恢复。
- 用户提交成功或点击"重新填写"按钮时清除 Pinia store 和 `sessionStorage` 中的表单数据。

此机制利用 Vue3 响应式系统 + Pinia store 作为主数据源、sessionStorage 作为持久化备份。具体实现细节（Pinia store 字段定义、序列化格式）在概要设计阶段确定。

### 4.5 生活方案

生活方案模块包含两个子功能：方案获取和每日打卡。

**方案获取**：用户提供身体信息、生活习惯和个人偏好三方面输入后，系统通过 Dify 工作流并行生成两部分内容——饮食方案（早餐、午餐、晚餐、加餐，含时间节点和具体内容）和运动方案（晨间、晚间、周末，含时间和项目），以结构化形式展示。方案内容由 DeepSeek 模型结合医学知识库和用户个人数据生成。

**方案排序与时段映射**：life_plans 表中的 order（排序）字段为整数，控制方案项在界面上的显示顺序，order 值越小越靠前。order 值与业务时段的映射约定如下：
- 饮食方案：1=早餐、2=午餐、3=晚餐、4=加餐
- 运动方案：1=晨间、2=晚间、3=周末

此映射约定用于前端渲染时按时段分组展示方案项，以及打卡分析时按类型维度统计完成率（详见 4.7 节）。具体映射值可在开发阶段根据 Dify 工作流输出格式微调。

**方案调整**：用户可以对已生成方案提出修改意见，系统根据反馈重新生成方案。

**每日打卡**：在方案展示页中，每条饮食/运动项旁提供打卡按钮。用户完成对应事项后可点击打卡，记录完成状态和时间。打卡记录通过 punch_in 表的 plan_id 字段关联到具体的 life_plans 方案项，使得打卡分析能够针对具体方案项进行依从性分析（而非仅按饮食/运动类型笼统统计）。

**方案为空时**：若用户尚未生成任何方案，展示引导页，提示用户先完成风险预测或直接生成方案。

**验收标准**：
- AI 生成方案至少包含 4 条饮食项（覆盖早/中/晚/加餐）和 3 条运动项（覆盖晨间/晚间/周末），方案内容在 15 秒内开始返回。
- 用户在方案页对任意方案项点击打卡后，打卡状态即时更新（1 秒内反馈），且该打卡记录可追溯对应的方案项。

### 4.6 健康资讯

系统通过 Dify 工作流自动生成健康资讯文章，文章内容由 DeepSeek 模型生成。工作流分两阶段运行：
1. **分类生成**：基于用户健康信息生成4个推荐资讯分类标签（饮食指导、运动指南、生活习惯、糖尿病知识科普，基于项目知识库中5份糖尿病 docx 文档的内容范畴推断）。用户健康信息的数据来源优先级为：（1）优先取 user_risk_info 表中该用户最新一条记录中的年龄、性别、BMI、家族史、糖尿病类型等字段；（2）若 user_risk_info 表无记录，降级取 users 表中的注册基本信息（年龄、性别等如有存储）；（3）若均无有效健康数据，降级为通用分类模式——不依赖个人数据，生成面向普通人群的通用资讯分类标签。
2. **文章生成**：用户选择一个分类标签后，系统生成完整的文章（标题、标签列表、正文内容）。

文章正文以 Markdown 格式存储（articles 表的"正文"字段为 Markdown 文本），前端渲染时使用 Markdown 解析器（如 marked.js）将 Markdown 转换为 HTML 展示。选择 Markdown 格式的理由：（1）Dify 工作流中 LLM 输出 Markdown 是自然且低成本的格式；（2）Markdown 支持标题层级、列表、加粗等排版需求，且前端渲染成熟；（3）纯文本表达能力不足，HTML 对 LLM 生成来说标记噪声过高。此格式选择为基于技术合理性的推断，可在开发阶段根据 Dify 工作流实际输出格式调整。

用户可浏览推荐资讯列表、查看文章详情、将文章加入收藏夹、从收藏夹取消收藏、查看已收藏文章列表。

**验收标准**：
- 用户选择分类标签后，系统在 15 秒内生成并展示完整的文章（含标题、标签、正文）。
- 收藏/取消收藏操作在 1 秒内完成状态更新，且刷新后状态保持。

### 4.7 打卡记录与分析

系统记录用户每日的饮食打卡和运动打卡数据（打卡时间、打卡类型、完成状态、备注、关联的方案项ID）。打卡数据来源于生活方案模块中的打卡操作——punch_in 表通过 plan_id 外键关联到 life_plans 表的方案项，使得每条打卡记录可追溯到具体方案项（如"4月15日早餐-燕麦粥"）。此关联关系支持两类分析维度：
- **按类型汇总**：统计饮食/运动打卡的总次数、完成率（基于 punch_type 字段）。
- **按方案项依从性分析**：统计各方案项的打卡完成率，识别用户对特定饮食/运动建议的执行偏差（基于 plan_id 关联查询）。

打卡分析功能通过 Dify 工作流对用户的打卡数据进行汇总和趋势分析，分析内容由 DeepSeek 模型生成，帮助用户了解自身的方案执行情况和依从性变化。

**验收标准**：
- 打卡分析至少包含以下维度：按饮食/运动类型的完成率、近 7 天完成趋势、依从性变化评语。
- 打卡记录列表支持按日期范围和打卡类型筛选。

### 4.8 AI 智能助手

这是一个统一的自然语言对话入口，背后是一个完整的 Dify Agent（而非简单的聊天机器人），具备工具调用能力（ReAct 或 Function Calling 模式）。Agent 挂载了 Text2SQL 数据库工具和数据库结构知识库，用户可以通过自然语言完成以下操作：

- 回答糖尿病相关知识问题
- 触发风险预测流程
- 生成个性化生活方案
- 查询和修改个人信息
- 查看打卡记录和分析
- 获取 AI 生成的健康生活建议（此类建议内容存储在 life_advice 表中，用户可在 AI 助手对话历史中回溯查看）

所有操作最终由 DeepSeek 模型完成自然语言理解、工具选择决策和回复生成，Dify Agent 负责工具定义、执行调度和结果汇总。

关于 life_advice 表：该表用于存储 AI 助手在对话中生成的健康生活建议（标题、标签、内容），作为"AI 健康建议"功能的持久化载体。用户可在 AI 助手的对话历史中查看过往建议，也可通过"我的"页面中的"健康建议"入口（基于推断的功能入口，位于个人中心子页面列表中）直接浏览已生成的所有建议列表。此功能归属为 AI 智能助手模块的子功能，无需独立的功能模块章。

**健康建议的触发机制**：健康生活建议的生成由 Dify Agent 根据对话上下文自主决策——当用户在对话中表达健康管理相关意图（如询问"我应该怎么调整生活习惯""给我一些饮食建议""帮我分析现在的健康状况"等）时，Agent 判断需要生成结构化健康建议后调用 Text2SQL 工具将建议内容写入 life_advice 表。Agent 在回复中告知用户"已为您生成一份健康建议，可在'我的-健康建议'中查看"。用户不需要在前端点击"生成健康建议"按钮——健康建议是对话的自然产出，而非独立的功能入口。此设计基于以下推断：（1）Agent 模式的本质是由模型自主决策何时调用工具，预设触发条件与 Agent 的灵活性相悖；（2）健康建议产出后自动存储于 life_advice 表，用户可在对话历史或"我的"页面中回溯查看，不会丢失。具体触发判断逻辑（Agent 系统提示词中的建议生成触发规则）在 Dify Agent 配置阶段定义。

AI 智能助手与医师咨询的区别在于：前者是功能聚合型的通用助手，可执行平台各类操作；后者是角色扮演型的领域专家，侧重健康咨询对话。

**访问入口**：AI 智能助手以全局悬浮按钮（FAB，Floating Action Button）的形式提供入口，位于主界面右下角，用户从任意页面均可一键唤起助手对话窗口。此设计选择基于以下推断：（1）AI 助手作为统一的自然语言操作入口，需要具备"随时可达"的特性，而 Tab 栏受限于固定位置和页面跳转开销；（2）原始项目任务文档中底部导航栏已定义5个固定 Tab（首页/咨询/生活方案/资讯/我的），未包含 AI 助手；（3）AI 助手的 Agent 模式本质上是一个跨模块的系统级服务，不属于某个具体的内容模块。此设计为基于功能特性的推断，最终入口形式可在架构设计阶段根据 UI 设计方案调整（例如也可作为第六个底部 Tab 或首页内的固定入口卡片），但需确保用户能在不超过一次点击的范围内触达该功能。

**未登录用户点击 FAB 的行为**：未登录用户点击 FAB 按钮时，AI 助手对话窗口仍然弹出，但窗口内不展示对话输入区域，而是展示登录引导提示（如"请先登录后使用 AI 智能助手"）和跳转至登录页的按钮。此设计基于以下推断：（1）FAB 作为全局可见入口应保持一致的即时反馈——点击即弹出对话窗口，而非无响应或仅在原地提示；（2）未登录状态下 AI 助手无法获取 user_id 以完成用户相关的工具调用和上下文绑定，因此需引导登录而非展示受限的对话能力。具体引导文案和视觉样式在 UI 设计阶段确定。

**会话管理**：用户打开 AI 助手对话窗口时默认创建新会话（不传 conversation_id），Dify Agent 返回新会话 ID 后前端保存至 Pinia `chatStore`（同时持久化至 localStorage 作为备份）。Pinia store 维护当前活跃对话的 `assistantConversationId`，后续对话消息自动携带该 ID 以保持上下文连续性。历史对话列表通过 Dify Agent 的会话列表 API 获取（系统需提供 GET /api/assistant/conversations 端点，Express 代理层转发至 Dify Agent 会话列表接口），用户可从历史会话列表中选择并恢复对话。会话不设置自动过期，由用户在 UI 中手动删除。

**验收标准**：
- AI 助手能正确响应至少以下 5 类自然语言意图：知识问答、风险预测触发、方案生成、个人信息查询、打卡记录查询。
- 助手对话窗口从任意页面可通过 FAB 一键唤起，唤起时间不超过 1 秒。

### 4.9 智能管理（管理员）

管理员通过自然语言对话界面操作后台 SQLite 数据库。核心能力包括：

- **查询**：查看任意数据表的内容（如所有用户、所有文章、打卡记录等），支持条件筛选。
- **新增**：向数据表中插入新记录。
- **修改**：更新已有记录。
- **删除**：删除指定记录。
- **操作追溯**：记录管理员的数据库操作历史（基于任务文档中"记录操作历史"的描述，推断需要一张操作日志表来存储操作类型、操作时间、操作内容等信息）。

智能管理模块覆盖原始需求中提到的以下管理场景：
- **打卡信息管理**：管理员可通过自然语言查询指定用户的打卡记录、统计打卡完成率、按日期范围筛选打卡数据、修正异常打卡记录等。
- **健康资讯管理**：管理员可通过自然语言查看已生成的资讯文章列表、按分类或时间筛选、修改文章内容、删除不适用的文章、查看各文章的收藏数据等。

所有操作通过 Dify Agent 将自然语言转换为 SQL 语句（由 DeepSeek 模型完成自然语言到 SQL 的转换），经 Express 服务接口执行并返回结果。

**验收标准**：
- 管理员通过自然语言完成一次完整 CRUD 操作（如"新增一位医生，姓名张三，科室内分泌科"），全流程在 10 秒内完成并返回操作结果。
- 管理员的所有数据库修改操作均可追溯（含操作类型、操作时间、操作内容），操作日志不可删除。

### 4.10 用户认证与会话管理

本节补充用户登录、会话保持和服务端鉴权的完整机制。

**认证流程**：用户提交用户名和密码后，密码通过HTTPS安全通道传输至服务端，由服务端使用bcrypt算法进行哈希校验。具体流程：服务端对用户输入的密码计算bcrypt哈希后与数据库中存储的哈希值比对，匹配则生成JWT Token（Payload含user_id和role字段），返回给前端。

**会话保持**：采用 JWT（JSON Web Token）无状态会话机制。Token 由服务端使用密钥签名，设置合理的过期时间（推荐 24 小时）。前端将 Token 存储在 localStorage 中，每次 API 请求在 Authorization 请求头中以 `Bearer <token>` 格式携带。服务端中间件校验 Token 签名和有效期，提取 user_id 和 role 注入请求上下文。

**鉴权方式**：
- 前端层面：读取 Token 中的 role 字段，控制界面元素的显隐（如管理员菜单项仅 role=admin 时渲染）。
- 服务端层面：Express 中间件校验 Token 后，对管理员专属接口（如 `/execute/` 数据库操作）检查 role=admin，拒绝非管理员请求并返回 403。

**Vue3 SPA 的登录态共享**：在 Vue3 SPA 架构下，所有页面组件运行在同一 JavaScript 运行时中，登录态通过 Pinia `authStore` 统一管理——`authStore` 持有 `token`、`role`、`userInfo` 等响应式状态，同时将 Token 持久化至 localStorage。所有 Vue 组件通过 `useAuthStore()` 直接访问登录状态，Vue 响应式系统自动同步所有组件的 UI 更新。用户登录成功后 `authStore` 更新状态，所有依赖该状态的组件（导航栏、路由守卫、API 拦截器）自动响应变更。登出时 `authStore` 清除状态并清空 localStorage。具体实现方式见 1.1 节。

**密码加密**：用户密码使用 bcrypt 算法进行哈希存储。注册和修改密码时，服务端生成随机盐值并计算 bcrypt 哈希后存入 users 表的 password 字段。登录验证时服务端对用户输入的密码重新计算 bcrypt 哈希并与数据库中的哈希值比对。密码不应以任何形式明文存储或传输日志。

**管理员鉴权**：管理员接口在 JWT role 校验之外，额外校验请求来源的合理性（如检查 Token 是否在合理的使用时效内）。管理员的数据库操作通过 Express `/api/admin/chat` 端点（SSE 流式对话）完成——管理员在智能管理界面中以自然语言输入操作指令，Express 代理转发至 Dify admin-manager-agent，Agent 将自然语言转换为 SQL 后通过 Text2SQL 工具回调 `/api/admin/execute` 端点执行。AI 助手的 Text2SQL 操作（普通用户通过 AI 助手对话触发）同样经 `/api/admin/execute` 端点执行，但走 Dify Agent 回调路径（非浏览器直连）。`/api/admin/execute` 端点采用双认证模式，根据请求来源区分鉴权路径：

- **浏览器直连场景**（管理员通过智能管理界面操作）：请求携带用户 JWT Token，接口校验 Token 有效性后根据 Token.role 进行分级鉴权——role=admin 的用户可执行任意 SQL 操作（查询/新增/修改/删除所有数据表）；role=user 的用户仅限操作与当前用户本人相关的数据（通过 Token 中的 user_id 进行行级权限约束，如仅可查询/修改本人的打卡记录、个人信息、风险预测记录等），不得越权操作其他用户数据。
- **Dify Agent 回调场景**（AI 助手对话中触发 Text2SQL 操作）：请求携带系统级 API Key（`DIFY_SERVICE_API_KEY`，见 7.5 节）和请求体中的 user_id 参数。Express 验证 API Key 以确认请求来源为可信的 Dify 服务后，以 user_id 作为行级权限基准，仅允许操作与该 user_id 关联的本人数据。

此分级鉴权逻辑需在 Express 端点实现中根据执行的 SQL 语句类型和目标表进行权限检查。管理员操作日志表（admin_logs）的写入不受行级限制——user 角色的操作同样记录日志（操作类型标注为"user_text2sql"以区分管理员操作）。双认证模式的具体实现细节（API Key 校验中间件、请求体参数名等）在概要设计阶段定义。

**访问控制矩阵**：以下表格定义各页面/功能模块的访问权限边界——即哪些页面可公开访问（无需登录），哪些页面需用户认证后方可访问。

| 页面/功能模块 | 公开访问 | 需登录（普通用户） | 需登录 + admin 角色 | 说明 |
|-------------|---------|------------------|-------------------|------|
| 系统首页 | 是 | — | — | 轮播Banner、医生展示、科普文章列表、糖尿病类型科普均公开 |
| 医师咨询（医生列表/详情） | 是 | — | — | 浏览医生信息公开；发起对话需登录 |
| 医师咨询（发送对话消息） | — | 是 | — | 需 JWT Token 认证 |
| 健康资讯（文章列表/详情） | 是 | — | — | 浏览资讯公开；生成/收藏需登录 |
| 健康资讯（生成/收藏操作） | — | 是 | — | 需 JWT Token 认证 |
| 个人中心（个人主页） | — | 是 | — | 需 JWT Token 认证 |
| 糖尿病风险预测 | — | 是 | — | 需 JWT Token 认证 |
| 生活方案（方案展示/打卡） | — | 是 | — | 需 JWT Token 认证 |
| 打卡记录与分析 | — | 是 | — | 需 JWT Token 认证 |
| AI 智能助手（FAB 入口可见） | 是 | — | — | FAB 按钮所有用户可见；实际对话需登录 |
| AI 智能助手（发送对话消息） | — | 是 | — | 需 JWT Token 认证 |
| 健康建议（查看历史列表） | — | 是 | — | 需 JWT Token 认证 |
| 智能管理（管理后台） | — | — | 是 | 需 JWT Token + role=admin |
| 登录/注册页面 | 是 | — | — | 公开访问 |

未登录用户访问"需登录"页面时，前端路由守卫检测到无有效 Token 后自动跳转至登录页。登录成功后根据来源路径回跳至目标页面。管理员专属页面在普通用户登录后前端不渲染入口，且后端接口校验 role=admin 后返回 403。

**Token 过期处理**：JWT Token 过期时间设置为 24 小时（见 7.5 节 `JWT_EXPIRES_IN` 配置项），Token 可能在用户操作过程中过期（如长时间停留在某页面后继续操作、跨天使用平台等）。为避免 Token 在用户操作中途过期导致数据丢失或体验中断，系统需在以下层面统一处理 Token 过期：

- **前端 HTTP 拦截器**：所有 API 请求（通过 Axios 拦截器）统一处理响应。当收到 401 状态码且错误码为 `AUTH_REQUIRED` 时，拦截器执行以下逻辑：（1）清除 Pinia `authStore` 中的 Token 及 localStorage 中的持久化副本；（2）展示非阻断性提示条（Toast 或顶部横幅，"登录已过期，请重新登录"）；（3）提供"重新登录"按钮，点击后跳转至登录页，登录成功后回跳至当前页面。
- **对话中 Token 过期**（SSE 流式接口）：Token 在对话进行中过期时，Dify 代理端点的 JWT 认证中间件返回 401 错误，前端 fetch 请求的响应状态码为 401，触发上述 Axios 拦截器逻辑。当前对话窗口保持打开状态，已接收的消息内容不丢失。
- **多步骤表单中途过期**：风险预测的多步骤表单数据已通过 Pinia store + `sessionStorage` 持久化（见 4.4 节），Token 过期触发重新登录后，Pinia store 从 sessionStorage 恢复，表单状态不受 Token 过期影响。
- **Token 过期全局同步**：Axios 拦截器拦截到 401 后调用 `authStore.clearAuth()`，Pinia 响应式系统自动通知所有依赖组件更新 UI 状态（隐藏需登录的功能入口、显示登录按钮等）。

### 4.11 医学免责声明

本平台所有由 AI 生成的内容（包括但不限于医师对话回复、风险预测建议、生活方案、健康资讯文章、AI 助手建议）均基于 DeepSeek 大模型和医学知识库自动生成，**不构成正式医疗诊断、处方或治疗建议**。用户若存在健康问题，应及时就医并遵从专业医师的指导。

**免责声明交互设计**：

- **首次使用 AI 功能前的免责确认弹窗**：用户首次访问以下任一 AI 功能入口时（医师对话、风险预测提交、方案生成、资讯生成、AI 助手对话），前端弹出免责声明确认弹窗，展示完整免责条款文案。用户点击"已知晓并同意"后方可继续使用该功能；点击"暂不使用"则返回上一页面。弹窗底部注明"本弹窗仅在首次使用时展示，后续使用不再提示"。确认状态存储在 localStorage 中，跨会话保持。

- **AI 生成内容底部的固定免责提示**：所有 AI 生成内容（医师对话消息、风险预测结果页、生活方案展示页、健康资讯文章详情页、AI 助手对话消息、健康建议详情）底部固定展示免责提示文案："以上内容由 AI 自动生成，仅供参考，不构成医疗诊断或治疗建议。如有健康问题，请及时咨询专业医师。"提示文案以灰色小字、浅色背景条形式呈现，位于内容区域末尾，与正文保持视觉区分。

- **医师对话界面免责标识**：在医师对话界面的顶部或输入框上方持续显示固定提示条"本对话由 AI 虚拟医师提供，回复内容仅供参考"，以半透明背景条形式呈现，确保用户在对话全程可见。

---

## 5. 数据需求

平台需持久化存储以下数据（基于项目知识库中 db.txt 定义的数据库结构，并根据功能需求补充必要字段）：

- **用户账号信息**（users）：用户ID、用户名、密码（bcrypt 哈希）、头像、角色（role，TEXT，CHECK(role IN ('user', 'admin'))，默认值 'user'）。角色字段用于登录后区分普通用户和管理员的功能入口与接口权限。
- **医生信息**（doctor_information）：医生ID、姓名、科室、职称、简介、头像、对话 Token（chat_token，TEXT）。chat_token 存储对应医生 Dify 聊天助手的 API 访问令牌，格式为 `app-XXX`（其中 `app-XXX` 为 Dify 平台为该聊天助手应用生成的 API Secret）。chat_token 仅在服务端 Express 代理层使用——Express 在收到前端的 `/api/chat/doctor/:id` 请求后，从本表读取对应医生的 chat_token，以此 Token 向 Dify 对话接口发起请求。chat_token 不暴露给前端。
- **科普文章**（articles）：文章ID、标题、封面、作者、发布时间、正文（Markdown 格式的 TEXT 字段）、分类、阅读量。正文采用 Markdown 格式存储，前端使用 Markdown 解析器渲染为 HTML 展示。
- **糖尿病类型信息**（diabetes_types）：类型ID、名称、图片、病因、表现、治疗方式。
- **文章收藏**（article_collections）：收藏ID、用户ID、文章ID。
- **用户风险信息**（user_risk_info）：用户ID、年龄、性别、身高、体重、家族史、腰围、收缩压、妊娠状态、原始输入信息、疾病类型。
- **生活方案**（life_plans）：方案ID、用户ID、类型（饮食/运动/其他）、排序（order，INTEGER，控制显示顺序，与时段映射约定见4.5节）、时间、标题、内容。
- **生活建议**（life_advice）：建议ID、用户ID、标题、标签、内容。该表存储 AI 智能助手在对话中为用户生成的健康生活建议内容，用户可通过 AI 助手对话历史或个人中心入口回溯查看。
- **打卡记录**（punch_in）：打卡ID、用户ID、方案项ID（plan_id，INTEGER，FOREIGN KEY REFERENCES life_plans(id)）、打卡时间、打卡类型（饮食/运动）、完成状态（已完成/未完成）、备注。plan_id 外键将每条打卡记录关联到具体的方案项，支撑按方案项维度的依从性分析。
- **管理员操作日志**（admin_logs）：日志ID、管理员用户ID、操作类型、操作时间、操作内容（SQL 语句或自然语言描述）、操作结果。该表用于追溯管理员的数据库操作历史，支持查询和审计。

平台存在三条数据操作路径，需明确区分：

1. **常规 CRUD 路径**：标准业务操作（用户注册/登录、个人信息读写、打卡记录写入/查询、文章收藏/取消收藏、管理员操作日志查询等）通过第 6 节定义的 Express REST API 端点直接操作 SQLite 数据库。前端发起 HTTP 请求至 Express 服务，Express 执行业务逻辑后直接读写数据库。此路径适用于数据格式固定、业务逻辑明确的场景。

2. **AI 驱动的 Text2SQL 路径**：管理员的智能管理操作和 AI 助手的部分数据库查询操作通过 Dify Agent 的 Text2SQL 工具间接操作数据库。管理员通过 `/api/admin/chat` 端点（SSE 流式对话，见 6.10 节）以自然语言描述操作意图，Express 代理转发至 Dify admin-manager-agent，Agent 借助 DeepSeek 模型将自然语言转换为 SQL 语句后，调用 Express 的 `/api/admin/execute` 端点执行。AI 助手对话中的普通用户同样以自然语言描述操作意图，经 `/api/assistant/chat` 端点转发至 Dify diabetes-assistant-agent，Agent 在需要数据库操作时通过 Text2SQL 工具回调 `/api/admin/execute`。Express 端点内部进行分级鉴权：admin-manager-agent 回调携带系统级 API Key + user_id（管理员自身），可执行任意 SQL 操作（管理全库数据）；diabetes-assistant-agent 回调携带系统级 API Key + 当前普通用户的 user_id，仅限操作与该 user_id 关联的本人数据（通过请求体中的 user_id 进行行级权限约束）。此路径适用于需灵活查询、无法预定义接口的场景。此权限约束由 Express 端点内部分级鉴权逻辑和 Dify Agent 的系统提示词共同保证。

**Dify Agent 回调 `/api/admin/execute` 时的用户身份传递机制**：AI 助手对话场景中，用户请求经 Express 代理转发至 Dify Agent（`/api/dify/agent/:agent_id`），Dify Agent 在内部通过 Text2SQL 工具回调 Express 的 `/api/admin/execute` 端点时，HTTP 请求来自 Dify 服务器而非用户浏览器，用户浏览器的 JWT Token 无法直接传递到此回调路径。为解决此问题，`/api/admin/execute` 端点采用双认证模式：

- **浏览器直连场景**（管理员通过智能管理界面 `/api/admin/chat` 对话操作，及 `/api/admin/execute` 的直接调用——后者保留兼容但主要使用场景已由 `/api/admin/chat` 替代）：请求携带用户的 JWT Token（Authorization: Bearer \<jwt\>），Express 从 Token 中提取 user_id 和 role 进行分级鉴权——role=admin 可执行任意 SQL 操作（查询/新增/修改/删除所有数据表）；role=user 的用户仅限操作与当前用户本人相关的数据。
- **Dify Agent 回调场景**（AI 助手对话中触发 Text2SQL 操作）：Dify Agent 的 Text2SQL 工具配置为在回调请求中携带系统级 API Key（通过环境变量 `DIFY_SERVICE_API_KEY` 配置，用于验证请求来源为可信的 Dify 服务）并在请求体中附带 `user_id` 参数（由 Dify Agent 从对话上下文中获取——Express 在代理转发用户消息至 Dify Agent 时，将 `user` 参数设置为当前用户的 user_id，Dify Agent 在 Text2SQL 工具调用时将该 user_id 填入回调请求体）。Express 端点验证 API Key 有效性后，以请求体中的 user_id 作为行级权限约束的基准。

系统级 API Key（`DIFY_SERVICE_API_KEY`）与环境变量中其他 Dify API Key 一并管理（见 7.5 节）。双认证模式的具体实现细节（API Key 校验中间件、请求体 user_id 参数名、Dify Agent 工具配置中的回调请求模板）在概要设计阶段定义。

**Dify 平台能力验证任务**：上述双认证模式依赖 Dify 平台支持在 Text2SQL 工具回调请求体中动态引用对话上下文的 `user` 参数——即 Dify Agent 能够将 Express 代理转发时传入的 `user` 字段（当前用户的 user_id）透传至工具回调的 HTTP 请求体中。此能力并非所有 LLM Agent 平台的通用特性，需在开发环境搭建阶段作为前置验证任务实测确认。验证方法：在 Dify 平台上创建一个测试 Agent，挂载一个指向 Express 测试端点的 HTTP 工具，在工具回调请求体模板中引用 `{{user}}` 变量，通过 Express 代理发送测试消息并观察回调请求体中是否实际携带了 user_id。若 Dify 平台不支持此能力，采用备选方案——Express 服务端维护 session_id → user_id 映射表：前端首次调用 `/api/dify/agent/:agent_id` 时，Express 生成唯一的 session_id 并与当前 user_id 关联存入内存映射表（如 Map 或 Redis），在代理请求的 `user` 参数中传入 session_id；Dify Agent 工具回调 `/api/admin/execute` 时携带 session_id，Express 通过映射表反查 user_id 进行行级权限约束。映射表条目在用户登出或 Token 过期时清理。备选方案的具体实现细节在概要设计阶段定义（待主方案验证结果确定是否需要启用）。

前端在任何情况下均不直接连接数据库——三条路径均通过 Express 服务接口完成数据库读写。

3. **AI 内容生成持久化路径**：部分 AI 驱动的 POST 端点（POST /api/risk/predict、POST /api/plan/generate、POST /api/articles/generate）在触发 Dify 工作流生成 AI 内容后，Express 服务端需将生成结果解析并写入数据库，以便后续 GET 端点返回。此路径的基本流程为：前端请求 → Express 端点 → 调用 Dify 工作流 API → 接收 Dify 响应 → 解析 AI 生成内容 → 数据结构化 → INSERT/UPDATE 数据库 → 返回结果给前端。

   此外，**life_advice 表的写入**同样属于 AI 内容生成持久化路径的覆盖范围——AI 助手 Agent（diabetes-assistant-agent）在对话中通过 Text2SQL 工具调用 Express 的 `/api/admin/execute` 端点（Dify Agent 回调场景），将健康建议内容写入 life_advice 表。与上述三个 POST 端点不同的是，life_advice 的写入由 Agent 自主决策触发（而非前端显式请求），写入路径为：用户对话消息 → Express 代理转发至 Dify Agent → Agent 判断需生成健康建议 → Text2SQL 工具回调 `/api/admin/execute`（携带系统级 API Key + user_id）→ Express 执行 INSERT 语句写入 life_advice 表。此路径已在第 5 节"AI 驱动的 Text2SQL 路径"中说明，此处重申其属于 AI 内容生成持久化路径的覆盖范畴。

   具体的字段映射关系（Dify 输出字段 → 数据库表字段）和各端点的持久化处理细节在概要设计阶段定义。各 POST 端点的服务端处理流程简述见第 6 节对应子节。

**系统级 API Key 管理**：AI 助手 Agent（diabetes-assistant-agent）、管理员 Agent（admin-manager-agent）及各工作流（diabetes-risk-prediction、life-plan-generator、health-article-generator、punch-analysis）的 Dify API Secret 属于系统级配置，不属于用户级数据，不存储在数据库中。这些 API Key 通过 Express 服务端的环境变量或 .env 配置文件管理，推荐命名规范如下：
- `DIFY_API_BASE_URL`：Dify 平台 API 基础地址
- `DIFY_ASSISTANT_API_KEY`：AI 助手 Agent 的 API Secret
- `DIFY_ADMIN_API_KEY`：管理员 Agent 的 API Secret
- `DIFY_RISK_WORKFLOW_API_KEY`：风险预测工作流的 API Secret
- `DIFY_PLAN_WORKFLOW_API_KEY`：方案生成工作流的 API Secret
- `DIFY_ARTICLE_WORKFLOW_API_KEY`：资讯生成工作流的 API Secret
- `DIFY_PUNCH_WORKFLOW_API_KEY`：打卡分析工作流的 API Secret

医生聊天助手的 API Key（chat_token）因与医生记录一一对应，仍通过 doctor_information 表的 chat_token 字段管理（属于用户级数据）。系统级与用户级 API Key 的管理方式区分如上。各环境变量的详细说明和完整配置清单见 7.5 节。

**图片/头像字段的存储策略**：各表中定义的图片相关字段（users 头像、doctor_information 头像、diabetes_types 图片、articles 封面）采用以下分策略管理：
- 用户头像：通过文件上传端点（见 6.14 节）上传至服务器本地存储目录（如 `/static/uploads/avatars/`），数据库中存储相对路径。上传时校验文件类型（仅允许 JPEG/PNG/WebP）和大小（≤2MB）。
- 医生头像：在数据库初始化 SQL 脚本中以相对路径引用预置图片（存放于 `/static/images/doctors/` 目录），与预置医生记录同步部署。
- 糖尿病类型图片：与医生头像类似，预置图片存放于 `/static/images/diabetes/` 目录，初始化脚本中引用。
- 文章封面：由 Dify 工作流在生成文章时以外部 URL 形式填充，数据库中存储完整 URL 字符串。若工作流未返回封面 URL，前端渲染时使用默认占位图。
以上静态资源（上传目录和预置图片目录）通过 Nginx 托管并提供对外访问，具体路径映射见 7.4 节。

**初始数据要求**：系统启动后依赖以下预置数据才能正常运行，需在数据库初始化阶段（通过 SQL 脚本或初始化接口）完成以下数据的预填充：

- **医生信息**（doctor_information 表）：至少预置 3 位不同科室的医生记录（含姓名、科室、职称、简介、头像）。每位医生的 chat_token 字段在 Dify 平台创建对应聊天助手应用后获取并填入（格式为 `app-XXX`）。chat_token 的获取时机为开发阶段——在 Dify 平台上为每位医生创建独立的聊天助手应用，获取 API Secret 后填入数据库初始化脚本。
- **糖尿病类型科普内容**（diabetes_types 表）：预填充完整的糖尿病类型列表，至少包含：（1）1 型糖尿病（自身免疫性，胰岛β细胞破坏，需终身胰岛素治疗）；（2）2 型糖尿病（胰岛素抵抗为主，与生活方式密切相关，可通过饮食运动及药物控制）；（3）妊娠期糖尿病（妊娠期间发病，产后多数可恢复但未来糖尿病风险升高）；（4）其他特殊类型糖尿病（如 MODY、胰腺疾病继发性糖尿病等）。每条记录含病因、表现、治疗方式的完整描述文本。
- **管理员账号**（users 表）：通过数据库初始化 SQL 脚本直接插入一条默认管理员记录（username='admin'，password 为 bcrypt 哈希后的默认密码，role='admin'）。管理员首次登录后系统应强制跳转至密码修改页面，要求更换默认密码后方可继续使用管理功能。建议在后续版本中由管理员通过智能管理界面自行创建其他管理员账号。
- **科普文章**（articles 表）：建议预置 2-3 篇示例科普文章（标题、正文、分类、作者），使首页科普文章区域在无 AI 生成文章的情况下仍有内容展示。示例文章内容可采用 Markdown 格式手工编写，覆盖糖尿病基础知识和生活管理主题。

以上初始数据的填充方式推荐使用数据库初始化 SQL 脚本（在 SQLite 数据库文件创建时执行），以确保部署环境的可复现性。具体 SQL 脚本内容和执行时机在概要设计阶段确定。本章涉及的数据表对应的新增 API 端点的完整接口规格见第 6 节。

---

## 6. API 接口规格说明

本节列出平台各功能模块对应的核心后端接口。接口基于 Express 服务实现，部署在数据服务器上（默认端口 3000）。前端通过 HTTP 请求调用，所有需要认证的接口均需在 Authorization 请求头中携带 JWT Token（格式：`Bearer <token>`）。

**请求参数映射说明**：Express 代理层承担前端请求体字段名与底层 Dify API 参数名之间的映射职责。以下为关键的参数名映射约定，各代理端点在转发请求至 Dify API 时需按此映射转换参数名：

| Express 端点请求体字段 | Dify API 参数名 | 说明 |
|----------------------|----------------|------|
| `message` | `query` | 用户对话消息内容。Express 的 `/api/chat/doctor/:id` 和 `/api/assistant/chat` 端点接收前端 `message` 字段后，转发至 Dify 对话/Agent API 时映射为 `query` 参数 |
| `conversation_id` | `conversation_id` | 对话会话 ID，参数名一致，无需转换 |
| 各端点的业务字段（如 age, gender, height 等） | `inputs.{field_name}` | 工作流类型端点（如 `/api/risk/predict` 对应 `diabetes-risk-prediction` 工作流）的业务字段在转发至 Dify 工作流 API 时嵌套在 `inputs` 对象中。例如，前端发送 `{"age": 45, "gender": "男"}` → Express 转发至 Dify 时映射为 `{"inputs": {"age": 45, "gender": "男"}, "user": "..."}` |

此外，Dify 工作流的 `inputs` 变量名由各工作流在 Dify 平台上的定义决定，Express 代理层在转发时需将前端请求体中的业务字段名映射为工作流定义中对应的 `inputs` 变量名（若两者不一致）。为降低映射复杂度，建议在 Dify 平台上定义工作流 `inputs` 变量时优先采用与前端请求体字段名一致的命名。具体的字段映射表（前端字段名 ↔ Dify inputs 变量名）在概要设计阶段根据 Dify 工作流的实际 inputs 定义补充。

### 6.1 认证相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/auth/register` | 用户注册（用户名、密码），密码经 bcrypt 哈希后存储 | 否 |
| POST | `/api/auth/login` | 用户登录，验证凭据后返回 JWT Token（含 user_id、role） | 否 |
| POST | `/api/auth/logout` | 登出（前端清除 Token，服务端可选记录） | 是 |

端点 `/api/auth/register` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| username | string | 是 | 用户名，需全局唯一 |
| password | string | 是 | 密码，长度不少于8位，需包含字母和数字（前后端均需校验） |

端点 `/api/auth/login` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| username | string | 是 | 登录用户名 |
| password | string | 是 | 登录密码 |

### 6.2 用户相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| GET | `/api/user/profile` | 获取当前用户个人信息 | 是 |
| PUT | `/api/user/profile` | 修改当前用户个人信息（用户名、头像等） | 是 |
| PUT | `/api/user/password` | 修改密码（需提供旧密码验证） | 是 |

端点 `/api/user/profile` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| username | string | 否 | 修改后的用户名 |
| avatar | string | 否 | 头像文件的相对路径。头像通过独立的文件上传端点（POST /api/upload/avatar，见 6.14 节）上传后获取返回的相对路径，再将此路径作为本字段的值提交。若不上传新头像，可省略此字段 |

端点 `/api/user/password` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| old_password | string | 是 | 当前密码，用于身份验证 |
| new_password | string | 是 | 新密码，长度不少于8位，需包含字母和数字 |

### 6.3 风险预测相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/risk/predict` | 提交健康数据，返回风险评分和等级 | 是 |
| GET | `/api/risk/history` | 获取当前用户的历史风险预测记录。支持分页查询参数：page（页码，默认1）、pageSize（每页条数，默认20，最大100） | 是 |

端点 `/api/risk/predict` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| diabetes_history | string | 是 | 用户的糖尿病病史状态（如：健康、糖尿病前期、已确诊） |
| diabetes_type | string | 否 | 若已确诊，需填写糖尿病类型（1型/2型/妊娠期/其他特殊类型） |
| age | number | 是 | 用户年龄 |
| gender | string | 是 | 用户性别（男/女） |
| height | number | 是 | 身高（cm） |
| weight | number | 是 | 体重（kg） |
| waist | number | 否 | 腰围（cm），未提供时服务端按 4.4 节公式估算 |
| systolic_bp | number | 否 | 收缩压（mmHg），未提供时服务端按 4.4 节分档值估算 |
| family_history | string | 是 | 家族糖尿病史（有/无） |
| pregnancy | boolean | 否 | 是否妊娠，仅性别为女时有效 |

POST /api/risk/predict 的服务端处理流程：接收前端提交的健康数据 → 调用 Dify diabetes-risk-prediction 工作流 → 接收工作流返回的风险评分和等级 → 将原始输入信息和预测结果写入 user_risk_info 表 → 返回结构化响应给前端。工作流输出字段到 user_risk_info 表字段的映射关系在概要设计阶段定义。

### 6.4 医师咨询相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| GET | `/api/doctors` | 获取医生列表。支持分页查询参数：page（页码，默认1）、pageSize（每页条数，默认20，最大100） | 否（浏览） |
| GET | `/api/doctors/:id` | 获取单个医生详情 | 否（浏览） |
| POST | `/api/chat/doctor/:id` | 向指定医生发送消息（SSE 流式响应），请求体中携带对话内容和会话ID | 是 |
| GET | `/api/chat/doctor/:id/conversations` | 获取指定医生的历史对话会话列表（Express 代理层转发至 Dify 会话列表 API） | 是 |

端点 `/api/chat/doctor/:id` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| message | string | 是 | 用户发送的对话消息内容 |
| conversation_id | string | 否 | Dify 对话会话ID。首次对话不传（Dify 自动创建新会话），后续对话传入以保持上下文连续性 |

SSE 代理转发策略：Express 服务端根据 `:id` 从 doctor_information 表读取 chat_token，以该 Token 向 Dify 聊天助手 API 发起 SSE 流式请求。Express 以流模式（Transfer-Encoding: chunked）将 Dify 返回的 SSE 事件逐块透传至前端，不缓冲完整响应后再发送。每个 SSE 事件保持 Dify 原始格式（`data: {...}\n\n`），前端使用 fetch + ReadableStream 方式消费流数据。因认证 SSE 端点需在请求头中携带 JWT Token（Authorization: Bearer \<token\>），而浏览器标准的 EventSource API 不支持自定义 HTTP 请求头，故仅推荐使用 fetch API 实现流式消费。chat_token 始终保持服务端侧，不暴露给前端。

**SSE 流内错误事件处理**：Dify API 在对话过程中可能返回流内逻辑错误事件（如 `data: {"event": "error", "message": "..."}` —— Agent 工具调用失败、知识库检索异常、模型输出被安全审核拦截等场景），此类错误不同于网络层面的 SSE 连接中断（见 7.3 节健壮性降级规范），需要前端按以下策略处理：（1）前端在 ReadableStream 消费循环中解析每个 SSE 事件的 `event` 字段，当 `event` 为 `"error"` 时停止继续消费当前流，提取 `message` 字段中的错误描述；（2）根据错误类型分类处理——工具调用失败（如 Text2SQL 执行错误）展示"操作执行失败：{错误简述}"并允许用户重试或换一种方式提问；知识库检索异常展示"知识库暂不可用，AI 将基于通用知识回复"（若 Agent 降级继续回复）或"服务暂时中断，请重试"（若 Agent 无法继续）；安全审核拦截展示"消息未通过内容审核，请修改后重试"；（3）流内错误不影响已接收和渲染的消息内容——`event: "error"` 事件之前已成功解析的消息文本保留在对话界面中；（4）错误信息展示为对话界面内的警告气泡（区别于用户和 AI 的对话气泡），包含错误简述和可选的重试按钮（点击后重新发送上一条用户消息）。具体错误类型枚举、错误气泡样式和重试交互细节在概要设计阶段根据 Dify 错误事件的实际格式补充。此策略同样适用于 6.9 节 AI 智能助手的 SSE 端点。

### 6.5 生活方案相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/plan/generate` | 提交用户信息，触发生成饮食和运动方案（Dify 工作流） | 是 |
| PUT | `/api/plan/adjust` | 根据用户反馈调整方案 | 是 |
| GET | `/api/plan/current` | 获取当前用户的活跃方案 | 是 |

端点 `/api/plan/generate` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| health_info | object | 是 | 用户身体信息，含 age（number）、gender（string）、height（number，cm）、weight（number，kg）等字段。内部子字段待概要设计阶段补充 |
| preferences | object | 是 | 用户偏好信息，含 dietary（饮食偏好/禁忌）、activity（运动偏好/限制）等字段。内部子字段待概要设计阶段补充 |

端点 `/api/plan/adjust` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| plan_id | string | 是 | 需调整的方案ID |
| feedback | string | 是 | 用户对方案的修改意见（自然语言描述，如"减少晚餐碳水、增加周末运动强度"） |

POST /api/plan/generate 的服务端处理流程：接收前端提交的用户信息和偏好 → 调用 Dify life-plan-generator 工作流 → 接收工作流返回的饮食和运动方案内容 → 将方案项逐条解析并写入 life_plans 表（含类型、排序、时间、标题、内容）→ 返回方案列表给前端。方案项的排序(order)值由工作流返回或由 Express 按 4.5 节约定的时段映射自动分配。PUT /api/plan/adjust 的处理流程类似——接收修改意见后重新调用工作流，新生成的方案替换原有方案记录。

### 6.6 打卡相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/punch` | 记录一次打卡（含 plan_id、punch_type、completion_status、备注） | 是 |
| GET | `/api/punch/list` | 获取打卡记录列表。支持分页查询参数：page（页码，默认1）、pageSize（每页条数，默认20，最大100）；支持筛选参数：startDate、endDate（日期范围）、punch_type（打卡类型） | 是 |
| GET | `/api/punch/analysis` | 获取打卡分析结果（Dify 工作流生成） | 是 |

端点 `/api/punch` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| plan_id | number | 是 | 关联的方案项ID（来自 life_plans 表） |
| punch_type | string | 是 | 打卡类型（饮食/运动） |
| completion_status | string | 是 | 完成状态（已完成/未完成） |
| remarks | string | 否 | 备注信息，用户可填写打卡当天的感受、特殊情况等 |

### 6.7 健康资讯相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| GET | `/api/articles` | 获取文章列表。支持分页查询参数：page（页码，默认1）、pageSize（每页条数，默认20，最大100）；支持筛选参数：category（分类标签） | 否（浏览） |
| GET | `/api/articles/:id` | 获取文章详情 | 否（浏览） |
| POST | `/api/articles/generate` | 触发 AI 生成文章（Dify 工作流） | 是 |
| POST | `/api/articles/:id/collect` | 收藏文章 | 是 |
| DELETE | `/api/articles/:id/collect` | 取消收藏文章 | 是 |
| GET | `/api/articles/collections` | 获取当前用户的收藏文章列表。支持分页查询参数：page（页码，默认1）、pageSize（每页条数，默认20，最大100） | 是 |

端点 `/api/articles/generate` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| category | string | 否 | 用户选择的分类标签（饮食指导/运动指南/生活习惯/糖尿病知识科普）。不传此参数时，Dify 工作流进入分类生成阶段，返回推荐分类标签列表供用户选择；传入此参数时直接进入文章生成阶段 |

POST /api/articles/generate 的服务端处理流程：接收前端提交的分类标签选择 → 调用 Dify health-article-generator 工作流 → 接收工作流返回的文章标题、标签列表、Markdown 正文、封面 URL → 将文章结构化写入 articles 表 → 返回文章详情给前端。若 Dify 工作流在分类生成阶段（未传 category 参数），Express 先将返回的分类标签列表返回前端供用户选择，用户选择后再触发文章生成阶段。两阶段的具体实现方式在概要设计阶段确定。

### 6.8 糖尿病类型相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| GET | `/api/diabetes-types` | 获取所有糖尿病类型列表（含病因、表现、治疗方式） | 否（公开浏览） |
| GET | `/api/diabetes-types/:id` | 获取单个糖尿病类型的详细信息 | 否（公开浏览） |

以上两个端点与医生列表端点（6.4 节）一致，设为无需认证即可访问（公开浏览），支持首页糖尿病类型科普功能的正常展示。

### 6.9 AI 智能助手相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/assistant/chat` | 向 AI 助手发送消息（SSE 流式响应），由 Dify Agent 处理 | 是 |
| GET | `/api/assistant/advice` | 获取当前用户的健康建议历史列表（life_advice 表）。支持分页查询参数：page（页码，默认1）、pageSize（每页条数，默认20，最大100）。列表中每条记录已包含标题、标签、完整内容字段，无需独立的详情端点 | 是 |
| GET | `/api/assistant/conversations` | 获取 AI 助手的历史对话会话列表（Express 代理层转发至 Dify Agent 会话列表 API） | 是 |

端点 `/api/assistant/chat` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| message | string | 是 | 用户发送的自然语言消息内容 |
| conversation_id | string | 否 | Dify Agent 对话会话ID，用于保持多轮对话上下文 |

SSE 代理转发策略与 6.4 节医师对话接口一致——Express 服务端以流模式透传 Dify Agent 返回的 SSE 事件至前端，前端使用 fetch + ReadableStream 方式消费流数据（不使用 EventSource API，原因同 6.4 节：认证 SSE 端点需在请求头中携带 JWT Token，而 EventSource 不支持自定义请求头）。SSE 流内错误事件处理策略与 6.4 节一致（按 `event` 字段区分错误类型并分类处理）。

**life_advice 表的写入路径说明**：AI 助手 Agent 在对话中生成健康生活建议后，通过 Text2SQL 工具调用 Express 的 `/api/admin/execute` 端点（Dify Agent 回调场景）将建议内容（标题、标签、正文）写入 life_advice 表。此写入操作不通过独立的 `/api/assistant/advice` POST 端点完成，而是内嵌在 Agent 的工具调用链路中——Agent 自主决策生成建议后，在 Dify 平台侧调用 Text2SQL 工具，工具执行 `INSERT INTO life_advice ...` 语句，HTTP 请求经 `/api/admin/execute` 端点的 Dify 回调认证路径到达 Express 并执行。写入路径的详细流程见第 5 节"AI 驱动的 Text2SQL 路径"和"AI 内容生成持久化路径"段落。此设计意味着 life_advice 表不存在独立的 CRUD POST 端点，其写入完全由 Agent 在对话中自主触发。

### 6.10 管理相关

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/admin/chat` | 管理员通过自然语言对话界面操作后台数据库（SSE 流式响应）。Express 代理层将对话消息转发至 Dify admin-manager-agent，Agent 将自然语言转换为 SQL 后通过 Text2SQL 工具回调 `/api/admin/execute` 执行并返回结果。管理员对话上下文通过 conversation_id 保持 | 是 + admin |
| POST | `/api/admin/execute` | 执行 SQL 数据库操作。此端点不直接面向管理员浏览器——管理员通过 `/api/admin/chat` 对话间接触发（Dify Agent 回调场景）；AI 助手对话中的普通用户 Text2SQL 操作同样通过此端点（Dify Agent 回调场景）。采用双认证模式——浏览器直连场景（已由 `/api/admin/chat` 替代，保留兼容）通过 JWT Token.role 分级鉴权（admin 可执行任意 SQL，user 仅限操作本人数据）；Dify Agent 回调场景通过系统级 API Key + 请求体 user_id 参数鉴权（仅限操作对应 userId 的本人数据）。双认证机制详见第 5 节 Text2SQL 路径说明 | 是 + admin（浏览器直连）/ API Key（Dify 回调） |
| GET | `/api/admin/logs` | 获取管理员操作日志列表。支持分页查询参数：page（页码，默认1）、pageSize（每页条数，默认20，最大100） | 是 + admin |

端点 `/api/admin/chat` 请求体参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| message | string | 是 | 管理员的自然语言操作指令（如"查询所有用户""新增一位医生，姓名张三，科室内分泌科""删除ID为5的打卡记录"等） |
| conversation_id | string | 否 | Dify Agent 对话会话ID。首次对话不传（Agent 自动创建新会话），后续对话传入以保持上下文连续性 |

SSE 代理转发策略与 6.4 节医师对话接口一致——Express 服务端以流模式透传 Dify admin-manager-agent 返回的 SSE 事件至前端，管理员在对话界面中查看自然语言转 SQL 的执行过程和结果。前端使用 fetch + ReadableStream 方式消费流数据（不使用 EventSource API，原因同 6.4 节）。SSE 流内错误事件处理策略与 6.4 节一致（按 `event` 字段区分错误类型并分类处理）。

端点 `/api/admin/execute` 请求体参数（Dify Agent 回调场景）：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| sql | string | 是 | Dify Agent 生成的 SQL 语句（由 Agent 的 Text2SQL 工具自动填充，非管理员手写） |
| user_id | string | 是（Dify Agent 回调场景） | 当前操作用户的 user_id，由 Dify Agent 从对话上下文中获取后填入回调请求体，Express 以此作为行级权限约束的基准。仅在 Dify Agent 回调场景下使用——浏览器直连场景通过 JWT Token 获取 user_id，无需在请求体中传递 |
| api_key | string | 是（Dify Agent 回调场景） | 系统级服务间认证 API Key（`DIFY_SERVICE_API_KEY` 环境变量值），Express 验证后确认请求来源为可信的 Dify 服务。仅在 Dify Agent 回调场景下使用——浏览器直连场景通过 JWT Token 认证，无需在请求体中传递 |

端点 `/api/admin/execute` 在浏览器直连场景下的请求体参数（管理员直接调用，已由 `/api/admin/chat` 替代但仍保留兼容）：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| sql | string | 是 | 待执行的 SQL 语句 |

以上参数定义基于当前双认证模式设计。Agent 工具回调请求体的具体字段名（`sql`、`user_id`、`api_key`）需与 Dify 平台上 admin-manager-agent 和 diabetes-assistant-agent 的 Text2SQL 工具配置保持一致——即 Agent 工具回调请求体模板中的字段名应与本表定义的字段名匹配。若 Dify 平台对工具回调请求体有字段名限制或命名约束，参数名可在概要设计阶段根据实际平台能力微调。

### 6.11 Dify 工作流接口（内部代理）

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/dify/workflow/:workflow_id` | 代理转发至 Dify 工作流 API，触发工作流执行 | 是 |
| POST | `/api/dify/agent/:agent_id` | 代理转发至 Dify Agent API，触发 Agent 对话 | 是 |

以上 Dify 代理接口的请求体通用参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| inputs | object | 是（workflow） | Dify 工作流的输入变量键值对，具体 key 取决于各工作流定义（如风险预测工作流的 inputs 含 age/gender/height/weight 等字段，方案生成工作流的 inputs 含 health_info/preferences 等字段） |
| query | string | 是（agent） | Dify Agent 的用户输入消息 |
| conversation_id | string | 否 | 对话会话ID，用于保持多轮对话上下文 |
| user | string | 是 | 用户标识（当前登录用户的 user_id，由 Express 从 JWT Token 中提取后自动填充） |
| response_mode | string | 否 | 响应模式：`streaming`（流式，默认）或 `blocking`（阻塞）。SSE 代理转发策略与 6.4 节一致——Express 以流模式透传 Dify 返回的 SSE 事件至前端 |

各工作流的 `inputs` 变量完整定义（字段名、类型、是否必填、取值范围）和 Agent 的具体工具定义在概要设计阶段补充。

**Dify 工作流清单汇总**：以下列出平台所有需在 Dify 平台上创建的工作流/聊天助手/Agent 及其核心信息，供开发阶段对照创建：

| 工作流标识（推荐命名） | 类型 | 用途 | 所属功能模块 | 触发端点 | 核心 inputs 变量 | 输出→数据库持久化 |
|----------------------|------|------|------------|---------|-----------------|---------------------|
| `diabetes-risk-prediction` | 工作流 | 根据用户健康数据计算糖尿病风险评分并生成建议 | 4.4 糖尿病风险预测 | `/api/dify/workflow/:workflow_id` | `age` (number, 必填)、`gender` (string, 必填)、`height` (number, 必填)、`weight` (number, 必填)、`waist` (number, 可选，已在4.4节定义估算公式)、`systolic_bp` (number, 可选，已在4.4节定义估算公式)、`family_history` (string, 必填)、`pregnancy` (boolean, 仅女性，已在4.4节定义)、`diabetes_history` (string, 必填) | 输出写入 user_risk_info 表（见 6.3 节处理流程） |
| `life-plan-generator` | 工作流 | 根据用户身体信息和生活习惯生成个性化饮食与运动方案 | 4.5 生活方案 | `/api/dify/workflow/:workflow_id` | `health_info` (object, 必填，含age/gender/height/weight等已在4.5节定义)、`preferences` (object, 必填，含dietary/activity偏好，已在4.5节定义) | 输出写入 life_plans 表（见 6.5 节处理流程） |
| `health-article-generator` | 工作流 | 根据用户健康信息生成健康资讯分类标签和完整文章 | 4.6 健康资讯 | `/api/dify/workflow/:workflow_id` | `user_id` (string, 必填，用于查询用户健康数据，数据来源优先级已在4.6节定义)、`category` (string, 可选，用户选择的分类标签) | 输出写入 articles 表（见 6.7 节处理流程） |
| `punch-analysis` | 工作流 | 对用户打卡记录进行汇总分析和趋势解读 | 4.7 打卡记录与分析 | `/api/dify/workflow/:workflow_id` | `user_id` (string, 必填)、`date_range` (object, 可选，含start/end日期，已在4.7节定义筛选支持) | 不持久化（分析结果即时返回，不写入数据库） |
| `diabetes-assistant-agent` | Agent | 通过工具调用完成知识问答、风险预测、方案生成、信息查询等综合操作 | 4.8 AI 智能助手 | `/api/dify/agent/:agent_id` | `query` (string, 必填，用户的自然语言消息，已在6.9节定义) | 健康建议输出写入 life_advice 表（由 Agent 工具调用触发） |
| `admin-manager-agent` | Agent | 将管理员的自然语言指令转为SQL操作数据库 | 4.9 智能管理 | `/api/dify/agent/:agent_id` | `query` (string, 必填，管理员的自然语言指令，已在6.10节定义) | 操作结果写入 admin_logs 表（操作日志） |
| `doctor-chat-{id}` | 聊天助手 | 以特定科室医生的角色进行一对一健康咨询对话 | 4.2 医师咨询 | `/api/chat/doctor/:id` | `query` (string, 必填，用户的对话消息，已在6.4节定义) | 不持久化（对话内容即时返回，不写入数据库） |

说明：
- 聊天助手类型（`doctor-chat-{id}`）：每位医生在 Dify 平台上为独立的聊天助手应用，拥有独立的系统提示词、知识库和对话参数。`{id}` 为 doctor_information 表的主键，chat_token 存储在对应医生记录的 chat_token 字段中（已在5节定义）。
- 工作流类型：通过 Dify 工作流 API 触发，`inputs` 变量中标注"必填"的字段前端和后端均需校验，标注"可选"的字段在用户未提供时由工作流内部使用默认值或估算公式（具体公式已在各功能章节定义）。
- Agent 类型：通过 Dify Agent API 触发，Agent 挂载的工具链（Text2SQL 工具、数据库知识库等）在 Dify 平台上配置，工具定义在概要设计阶段补充。
- inputs 变量的详细定义（类型、取值范围、校验规则）已在对应功能章节（4.2-4.9）和数据需求章节（5节）中分散说明，本表仅做集中索引。标注"待概要设计阶段补充"的变量其完整字段定义留待概要设计阶段细化。

### 6.12 分页响应格式

列表类接口（标注支持分页查询参数的端点）在响应中返回以下统一分页结构：

```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "total": 150,
    "totalPages": 8
  }
}
```

- `data`：当前页的数据列表
- `pagination.page`：当前页码
- `pagination.pageSize`：每页条数
- `pagination.total`：符合条件的总记录数
- `pagination.totalPages`：总页数（由 total/pageSize 向上取整计算）

### 6.13 通用错误响应格式

所有接口在发生错误时返回统一 JSON 结构：

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "人类可读的错误描述"
  }
}
```

常见错误码：`AUTH_REQUIRED`（401，未登录或 Token 过期）、`FORBIDDEN`（403，权限不足）、`NOT_FOUND`（404，资源不存在）、`VALIDATION_ERROR`（422，请求参数校验失败）、`AI_TIMEOUT`（504，AI 接口超时）、`INTERNAL_ERROR`（500，服务端内部错误）。

### 6.14 文件上传

| 方法 | 端点 | 说明 | 认证 |
|------|------|------|------|
| POST | `/api/upload/avatar` | 上传用户头像。前端以 multipart/form-data 格式提交，服务端校验文件类型（仅允许 JPEG/PNG/WebP）和大小（≤2MB），保存至服务器本地存储目录后返回访问 URL | 是 |

头像上传端点的服务端处理流程：接收前端上传的文件 → 校验文件类型（检查 MIME 类型和文件扩展名）和大小 → 生成唯一文件名（如 `{user_id}_{timestamp}.{ext}`）→ 保存至服务器本地存储目录（默认 `/static/uploads/avatars/`）→ 更新 users 表中当前用户的头像字段为相对路径 → 返回头像访问 URL 给前端。用户修改头像时，新上传的头像覆盖旧文件（或保留旧文件、仅更新数据库中的路径引用——具体策略在概要设计阶段确定）。

前端用户头像的上传交互集成在个人信息编辑页面（4.3 节）中，用户点击头像区域触发文件选择对话框。医生头像和糖尿病类型图片为预置静态资源，通过 Nginx 直接托管（见 7.4 节），不通过此上传端点管理。

---

## 7. 非功能性需求

### 7.1 用户界面

- 界面以移动端尺寸（约375px宽）为设计基准，同时需要能在桌面浏览器中正常显示。
- 主色调、字体颜色、字体大小应形成清晰的视觉层次，各级标题、正文、辅助文字有可辨识的差异。
- 各页面交互模式保持一致——相同的操作在不同页面应产生相似的反馈。
- 降低用户记忆负担：关键操作入口在显著位置可见，无需用户记忆隐藏路径。
- 从用户使用习惯出发设计操作流程，而非从系统实现角度。

**设计系统基础参数**：以下为前端开发所需的最小设计参数集合，确保各模块页面的视觉一致性。具体色值和尺寸在 UI 设计阶段可微调。

**品牌主色调**：
- 主色（Primary）：`#4A90D9`（医疗健康蓝，传递专业、信赖、冷静的视觉感受）
- 主色浅色（Primary Light）：`#E8F1FB`（主色的 10% 透明度等效色，用于选中态背景、标签背景等）
- 主色深色（Primary Dark）：`#3A7BC8`（主色加深 10%，用于按压态、悬停态）
- 辅助色（Accent）：`#52C41A`（健康绿，用于成功状态、打卡完成、积极指标）
- 危险色（Danger）：`#FF4D4F`（用于错误状态、高风险标识、删除操作按钮）
- 警告色（Warning）：`#FAAD14`（用于中风险标识、警告提示）
- 中性色（Neutral）：文字主色 `#333333`、文字辅助色 `#666666`、文字禁用色 `#BFBFBF`、背景色 `#F5F5F5`、分割线 `#E8E8E8`、卡片白 `#FFFFFF`

**字体族栈**：`-apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", "Helvetica Neue", sans-serif`（优先使用系统原生中文字体，确保在各平台上的渲染一致性）。

**字号层级**：

| 层级 | 字号 | 行高 | 用途 |
|------|------|------|------|
| H1（页面主标题） | 20px | 28px | 各模块页面的一级标题（如"糖尿病风险预测"） |
| H2（区块标题） | 18px | 25px | 页面内的二级区块标题（如"饮食方案""运动方案"） |
| H3（卡片标题） | 16px | 22px | 文章卡片标题、医生姓名、方案项标题 |
| Body（正文） | 14px | 20px | 文章正文、对话消息、表单标签、列表项内容 |
| Caption（辅助文字） | 12px | 17px | 时间戳、来源标注、免责提示、次要说明文字 |

**基础间距尺度**（以 4px 为基准单位）：4px、8px、12px、16px、20px、24px、32px。推荐常用的间距依次为：元素内间距 8px、相关元素间距 12px、区块内间距 16px、区块间间距 24px、页面边距 16px（移动端）。

以上设计参数为基于移动端医疗健康类应用通用设计模式的推断，具体色值、字号和间距在 UI 设计阶段可根据视觉设计方案调整，但需保持各模块间的一致性。

**交互状态规范**：各模块页面和组件需统一处理以下三类中间交互状态，确保用户在等待、无数据和出错场景下获得一致的体验。

**加载中状态**：
- 页面级加载（首次进入页面等待数据）：展示居中加载动画（Spinner 或 Skeleton 骨架屏），骨架屏优先——各模块页面的骨架屏形状与该页面主要内容区域的布局一致（如文章列表页为 3-4 条横条骨架、方案展示页为卡片骨架），减少页面抖动感。
- 组件级加载（按钮点击后等待操作结果）：按钮展示加载态（按钮内 Spinner + 禁用交互），防止重复提交。按钮文本替换为"处理中..."或"生成中..."等动词进行时表述。
- AI 生成加载（方案生成、文章生成、风险分析）：因 AI 生成耗时较长（预期 15 秒内），使用包含进度提示的加载组件——展示当前阶段描述文本（如"正在分析您的健康数据...""正在生成饮食方案..."），搭配不确定进度的进度条动画。阶段描述文本由 Dify 工作流在不同处理阶段通过 SSE 事件推送，或由前端根据 SSE 事件类型推断阶段切换。

**空数据状态**：
- 列表类空数据（打卡记录列表、收藏列表、健康建议列表等）：展示居中的空状态插图（简洁线条风格插画）、友好提示文案（如"还没有打卡记录，去生活方案页开始打卡吧"）、操作引导按钮（如"去打卡"），引导用户执行首个操作以产生数据。
- 生成类空数据（尚未生成方案、尚未生成文章、尚未进行风险预测）：展示引导页，含功能简介（2-3 句说明该功能的用途和操作步骤）和明确的 CTA 按钮（如"开始风险预测""生成我的生活方案""生成健康资讯"）。
- 对话类空数据（医师对话窗口、AI 助手对话窗口首次打开）：展示欢迎语和输入引导——医师对话展示医生简介和推荐提问话题（3 条示例问题）；AI 助手展示助手能力简介（"我可以帮您：查询信息、生成方案、记录打卡..."）和推荐指令（2-3 条示例）。

**错误状态**：
- 网络错误（API 请求失败、SSE 连接中断）：按 7.3 节健壮性降级规范处理——展示统一错误组件（含错误提示文案和手动重试按钮）。
- 数据校验错误（表单字段校验失败）：在对应字段下方展示红色错误文本（12px），字段边框变为红色。表单提交按钮在存在校验错误时保持可点击——点击后焦点自动跳转至第一个错误字段并展示其错误提示。
- 权限错误（401 未登录、403 权限不足）：401 按 4.10 节 Token 过期处理策略执行（触发登录引导）；403 展示"无权限访问"提示页，含返回首页按钮（普通用户误入管理页面时）。

以上交互状态规范覆盖所有功能模块共有的中间状态场景。各模块特有状态的交互细节在模块详细设计中补充。具体 UI 组件（骨架屏形状、空状态插图、错误提示文案等）在 UI 设计阶段产出视觉稿。

### 7.2 性能

- 普通用户操作（页面跳转、表单提交、按钮点击）的结果反馈在 1 秒内完成，极端情况下不超过 3 秒。
- 涉及 AI 内容生成的操作（方案生成、文章生成、风险分析、AI 对话）允许更长的等待时间，但应提供加载状态提示，单次 AI 请求应在 15 秒内开始返回内容（基于大模型 API 调用的一般经验推断，此数字为合理预期而非硬性约束）。
- 数据同步操作（如打卡记录写入）在 1 秒内完成。
- 系统应保持 7x24 小时连续运行能力。

### 7.3 产品质量

- **正确性**：生成内容应基于专业医学知识库，风险评分计算准确；避免编造医学事实。
- **健壮性**：AI 接口异常时应有降级处理，不应导致页面崩溃或白屏；用户输入异常数据时应有前端校验和友好提示。具体降级规范如下：
  - **AI 服务完全不可用时**：展示统一的错误状态组件，含友好提示文案（如"AI 服务暂不可用，请稍后重试"）和手动重试按钮。不展示空白区域或技术性错误信息。
  - **响应超时处理**：所有 AI 接口超时阈值统一为 15 秒，超时后展示超时提示（如"响应超时，请点击重试"）并允许用户手动重试。不自动重试，避免重复提交请求加重服务端压力。
  - **历史数据缓存降级**：对于有历史生成数据的 AI 功能（如已生成的文章、方案、建议），当 AI 服务不可用时优先展示缓存的历史内容，并在顶部标注"上次生成时间"以告知用户内容非实时。
  - **流式接口（SSE）连接中断**：医师对话和 AI 助手等流式接口在 SSE 连接意外中断时，前端展示"连接中断，点击重试"提示条（不覆盖已有对话内容），保留已接收的消息内容，用户可点击重试恢复连接或重新发送最后一条消息。
- **可靠性**：打卡数据、用户信息等关键数据写入后不应丢失。
- **易用性**：新用户无需培训即可完成核心操作（浏览科普、风险预测、查看方案）。
- **安全性**：用户密码使用 bcrypt 哈希存储，不以明文形式出现在数据库或日志中；管理员接口需通过 JWT role 校验（role=admin）；API 请求通过 JWT Token 进行身份认证；密码修改需验证旧密码；敏感操作（删除数据）需二次确认。
- **可扩展性**：数据库结构预留扩展空间，新增功能模块不应牵动整体架构。
- **可移植性**：平台基于 Vue3 + Express（JavaScript/TypeScript 全栈 Web 技术）构建，天然支持跨操作系统运行——Vite 构建产物为静态 HTML/CSS/JS 文件，可在不同 Windows、Linux、macOS 服务器环境之间迁移部署，无需修改源代码。
- **兼容性**：前端界面需兼容主流现代浏览器（Chrome、Edge、Firefox、Safari 的最新两个主要版本），确保在不同浏览器内核下的页面渲染和交互行为一致。

### 7.4 部署架构

平台部署于原始需求规划的 3 台 Linux 服务器（8核16G内存）上，各服务器角色分工如下：

| 服务器 | 角色 | 部署组件 | 说明 |
|--------|------|---------|------|
| 服务器1 | 数据服务器 | SQLite、Express（端口3000）、Nginx（静态文件服务） | Express 提供 REST API 接口层，SQLite 存储所有业务数据，Nginx 托管前端 HTML/CSS/JS 静态文件。此服务器为系统的数据和逻辑中心 |
| 服务器2 | 系统运行服务器（主） | Nginx（反向代理 + 负载均衡） | 接收外部用户请求，将 API 请求反向代理至服务器1的 Express（端口3000），将静态资源请求反向代理至服务器1的 Nginx。与服务器3的 Nginx 共同组成负载均衡集群 |
| 服务器3 | 系统运行服务器（备） | Nginx（反向代理 + 负载均衡） | 与服务器2功能对等，共同组成 Nginx 集群。两台服务器通过 DNS 轮询或主备模式对外提供统一入口，实现请求分发和故障转移 |

**前端部署**：HTML/CSS/JS 等前端静态文件部署在服务器1的 Nginx 静态文件目录下。用户浏览器直接访问 Nginx 获取前端资源。

**API 路由**：用户浏览器发出的 API 请求（`/api/*`）先到达服务器2或服务器3的 Nginx，Nginx 将请求反向代理至服务器1的 Express 服务（`http://服务器1:3000`）。Express 处理业务逻辑后直接读写本机 SQLite 数据库。

**负载均衡**：服务器2和服务器3的 Nginx 组成集群，通过以下方式之一实现负载均衡和高可用：
- 方案A（DNS 轮询）：域名解析到两台服务器的 IP，由 DNS 实现轮询分发。
- 方案B（主备 + Keepalived）：两台 Nginx 通过 Keepalived 组成主备模式，虚拟 IP（VIP）对外提供服务，主节点故障时备节点自动接管。

具体负载均衡方案在部署设计阶段根据项目组可用的网络环境和域名条件确定。

**Dify 和 DeepSeek**：Dify 平台和 DeepSeek API 为外部云服务，不在本地服务器上部署。Express 通过 HTTP 请求调用 Dify API，Dify 内部调用 DeepSeek API 完成模型推理。此依赖关系意味着平台需要稳定的外网连接。

**静态资源托管**：Nginx 除托管前端 HTML/CSS/JS 文件外，还需配置以下静态资源目录的访问路径：
- `/static/uploads/avatars/`：用户头像上传目录（映射至服务器本地存储路径，如 `/var/www/static/uploads/avatars/`）
- `/static/images/doctors/`：预置医生头像目录
- `/static/images/diabetes/`：预置糖尿病类型图片目录

以上目录在 Nginx 配置中添加对应的 location 块，设置合理的缓存策略（如图片文件设置 `expires 7d`）。用户通过浏览器可直接访问这些静态资源 URL。前端引用头像和图片时使用相对路径（如 `/static/uploads/avatars/user_123.jpg`），由 Nginx 解析并返回对应文件。

**SQLite 数据可靠性说明**：SQLite 为文件型数据库，数据文件仅存在于服务器1的本地磁盘上，不具备主从复制或自动故障转移能力。当服务器1发生宕机、硬件故障或磁盘损坏时，API 服务和数据访问将全部中断，服务器2和服务器3的 Nginx 仅能提供静态资源负载均衡，无法接管数据服务。因此，虽然部署架构使用3台服务器，但在数据可用性层面实际为单点架构。项目应建立数据库文件的定期备份策略（如每日定时备份 SQLite 数据库文件至服务器2或外部存储），以降低数据丢失风险。具体备份方案在部署设计阶段确定。

### 7.5 环境配置

平台需通过环境变量管理以下配置项，推荐在 Express 服务端使用 `.env` 文件（开发环境）或服务器环境变量（生产环境）进行配置。所有敏感信息（密钥、API Secret）不得硬编码在源代码中或提交至版本控制系统。

**JWT 与安全配置**：

| 配置项 | 说明 | 示例值 |
|-------|------|--------|
| `JWT_SECRET` | JWT Token 签名密钥（至少32字符随机字符串） | `your-jwt-secret-key-min-32-chars` |
| `JWT_EXPIRES_IN` | JWT Token 过期时间 | `24h` |

**Dify API 配置**：

| 配置项 | 说明 | 示例值 |
|-------|------|--------|
| `DIFY_API_BASE_URL` | Dify 平台 API 基础 URL | `https://api.dify.ai/v1` |
| `DIFY_SERVICE_API_KEY` | Dify Agent 回调 Express 时的服务间认证 API Key（用于 `/api/admin/execute` 双认证模式中的 Dify 回调场景，见第 5 节） | `dify-service-key-xxxxxxxx` |
| `DIFY_ASSISTANT_API_KEY` | AI 助手 Agent 的 API Secret | `app-xxxxxxxxxxxxx` |
| `DIFY_ADMIN_API_KEY` | 管理员 Agent 的 API Secret | `app-xxxxxxxxxxxxx` |
| `DIFY_RISK_WORKFLOW_API_KEY` | 风险预测工作流的 API Secret | `app-xxxxxxxxxxxxx` |
| `DIFY_PLAN_WORKFLOW_API_KEY` | 方案生成工作流的 API Secret | `app-xxxxxxxxxxxxx` |
| `DIFY_ARTICLE_WORKFLOW_API_KEY` | 资讯生成工作流的 API Secret | `app-xxxxxxxxxxxxx` |
| `DIFY_PUNCH_WORKFLOW_API_KEY` | 打卡分析工作流的 API Secret | `app-xxxxxxxxxxxxx` |

**Express 服务配置**：

| 配置项 | 说明 | 示例值 |
|-------|------|--------|
| `PORT` | Express 服务监听端口 | `3000` |
| `SQLITE_PATH` | SQLite 数据库文件路径 | `./data/database.sqlite` |
| `UPLOAD_DIR` | 用户上传文件存储目录 | `./static/uploads/` |

以上配置项清单供部署阶段参考。开发阶段建议提供 `.env.example` 模板文件（含所有配置项名称和空值占位符），实际配置值由部署人员在部署环境填写。医生聊天助手的 chat_token 仍通过 doctor_information 表管理（属于用户级数据，见第 5 节），不纳入环境变量。

---

## 8. 范围与边界

### 8.1 在范围内

- 移动端优先的 Web 应用（**Vue3** + **Vite** 构建工具实现）
- 前端构建方式：采用 **Vue3 框架 + Vite 构建工具** 开发。Vue3 提供组件化开发（SFC .vue 单文件组件）、响应式状态管理（Pinia）、声明式路由（Vue Router）；Vite 提供开发服务器（HMR 热更新）和生产构建（代码分割、Tree Shaking、资源压缩）。第三方 UI 组件（如 Swiper 轮播组件、marked.js Markdown 解析器）通过 npm 安装管理，在 vite.config.ts 中配置按需引入或 CDN 外部化。**Cline + DeepSeek** 作为 AI 编程助手辅助前后端代码生成——Cline 调用 DeepSeek 大模型生成 Vue3 组件代码、API 调用代码、Express 路由处理逻辑等。此选择基于以下推断：（1）Vue3 是渐进式框架，学习曲线平缓，适合实训项目的开发周期；（2）Vite 提供极快的冷启动和 HMR，提升开发效率；（3）组件化架构消除 iframe 引入的复杂性和运行时开销；（4）Cline + DeepSeek 组合是本次实训指定的 AI 编程工具链。
- 前端源代码推荐目录结构（Vue3 + Vite 标准项目结构）：`src/views/`（页面级 Vue SFC 组件）、`src/components/`（可复用 Vue 组件）、`src/router/`（Vue Router 路由配置）、`src/stores/`（Pinia store 模块）、`src/api/`（API 请求封装模块，含 Axios 拦截器）、`src/assets/`（静态资源——图片、全局 CSS）、`public/`（不经过构建的静态文件）、`index.html`（Vite 入口 HTML）。具体目录命名和文件划分在概要设计阶段确定。
- DeepSeek 大模型通过 Dify 平台提供 AI 能力
- SQLite 数据库用于本地数据持久化
- 糖尿病风险预测（基于《中国2型糖尿病防治指南》评分体系）
- 个性化饮食与运动方案生成
- 多位 AI 医师的对话咨询
- 健康资讯自动生成与收藏管理
- 每日打卡记录与 AI 分析
- 自然语言 AI 助手（Agent 模式）
- 管理员自然语言数据库操作
- JWT 无状态会话管理
- bcrypt 密码哈希存储
- Express REST API 接口层

### 8.2 不在范围内

- 真实医生的在线问诊（平台上的"医师"均为 AI 虚拟角色）
- 医疗器械数据接入（如血糖仪自动同步）
- 药物管理与提醒
- 与医院 HIS 系统的对接
- 支付与商业化功能
- 鸿蒙原生应用的开发（该内容属于并行轨道 A2，为独立交付物）
- 金仓数据库的实际迁移（该内容属于并行轨道 A3，为独立交付物）
- 原生的 iOS / Android 应用

### 8.3 并行任务轨道（独立交付，非主系统的一部分）

以下5个并行轨道与本 Web 平台共享项目主题，但各自产出独立交付物，不属于主系统开发范畴：

- **A1 - 大模型开发**：说明系统中如何使用 DeepSeek 和 Dify 技术，提交技术应用文档。
- **A2 - 鸿蒙应用开发**：将核心功能模块用 ArkTS/ArkUI 实现为鸿蒙应用，提交可运行的鸿蒙项目。
- **A3 - 国产数据库应用**：基于金仓数据库建表并实现至少一个 CRUD 业务功能，提交国产数据库应用。
- **A4 - 单元测试**：后端核心功能 100% 覆盖、辅助功能 >=80% 覆盖（JUnit 5）；前端核心业务逻辑 100% 覆盖、工具函数 >=80% 覆盖（Vitest），提交测试报告和覆盖率截图。
- **A5 - 性能测试**：使用 WebRunner 对登录接口进行 50/100/200 并发的性能测试，关注 TPS、响应时间、错误率等指标，提交测试报告。

此外，项目代码需在太乙平台注册并绑定 Gitee/GitHub 进行开源发布，全体成员参与代码提交。开源发布需提交以下三项交付物：（1）**源代码打包**——完整的项目源代码压缩包，含 Vue3 前端（src/ 源码 + vite.config.ts）、Express 后端、数据库初始化脚本；（2）**项目文档**——含需求文档、概要设计说明书、部署说明、API 接口文档等；（3）**开源仓库地址**——Gitee 和/或 GitHub 仓库链接，确保仓库为公开状态且包含完整的提交历史。

---

## 9. 澄清说明

本文档对原始需求描述做了以下澄清与补充：

1. **导航结构**：原始需求仅列出功能模块，未说明模块间的组织方式。基于项目任务文档（任务2：系统首页）中明确的"底部 Tab 栏 + iframe 子页面"架构，本文将导航方式补充为具体描述。

2. **风险预测算法**：原始需求仅提及"精准预测糖尿病风险"，未说明预测依据。本文明确补充了基于《中国2型糖尿病防治指南（2020版）》评分体系（0-51分）的实现方式，并说明了当用户未提供腰围/收缩压时基于公式估算的降级策略——以上均来自项目任务5的技术指导文档。

3. **医师身份**：原始需求使用"名医对话""专家在线交流"等表述，容易引发"真实医生在线服务"的误解。本文明确说明平台上的"医师"为 AI 驱动的虚拟角色，避免下游产生合规风险。

4. **AI 助手与医师咨询的区分**：原始需求将两者混合描述。本文明确区分了智能助手（功能聚合型 Agent，可操作数据库）和医师咨询（角色扮演型聊天机器人，专注健康对话）的定位差异。

5. **数据库架构与操作路径**：原始需求未提及数据存储细节。本文补充了基于 db.txt 的完整数据表结构，并澄清了"前端 -> Dify Text2SQL -> Express -> SQLite"的数据操作路径——这一架构贯穿所有需要数据库读写的功能模块。

6. **管理员职责**：原始需求中"AI智能管理"表述模糊。本文将其明确为"自然语言操作数据库进行增删改查，并记录操作历史"，依据来自项目任务10的指导文档。

7. **健康资讯生成机制**：原始需求仅列出"健康资讯展示""健康资讯生成"，未说明生成流程。本文补充了"分类标签生成 -> 完整文章生成"的两阶段工作流模式，以及4个分类标签的内容范围，依据来自项目任务7的技术文档。

8. **打卡的数据来源**：原始需求将"生活方案"和"运动与饮食打卡"分开列出但未说明关联。本文明确了打卡操作是在生活方案展示页中针对具体方案项进行的，两者是同一业务流程的不同环节。

9. **非功能需求的时间预期**：原始需求中"用户操作在1秒内返回"对 AI 内容生成类操作不现实。本文区分了普通操作（1秒）和 AI 生成操作的合理预期（提供加载状态、15秒内开始返回），并标注这为合理推断而非原始需求的明确约束。

10. **安全需求补充**：原始需求的安全性描述为单一名词"安全性"，本文基于 Web 应用的通用实践补充了密码加密存储和权限校验两项具体安全需求，并标注为推断。

11. **iframe 跨模块通信**：原始需求和项目任务文档均未涉及 iframe 架构下的跨模块通信问题。本文在 1.1 节补充了登录态共享、FAB 渲染层级、AI 助手触发导航、iframe 间数据传递四项通信机制的设计原则（v3 新增，标注为基于架构特性的推断）。

12. **用户认证与会话管理**：原始需求未涉及认证机制的具体实现方式。本文新增 4.10 节，明确 JWT 无状态会话机制、Token 的生成/存储/传递/校验流程、前后端鉴权方式、iframe 间登录态共享、bcrypt 密码哈希存储等完整认证体系（v3 新增，标注为基于 Web 安全通用实践的推断）。

13. **数据模型补充**：原始 db.txt 定义的 users 表不含角色字段、punch_in 表不含方案项关联字段。本文在数据需求节中为 users 表增加 role 字段、为 punch_in 表增加 plan_id 外键，以支撑角色区分和打卡依从性分析功能（v3 新增，标注为功能需求驱动的数据模型补充）。

14. **life_advice 表功能归属**：原始 db.txt 定义了 life_advice 表但无对应功能模块。本文将其归属为 AI 智能助手模块的子功能（健康建议的持久化载体），在 4.8 节中补充说明其使用上下文（v3 新增，标注为基于数据模型与功能模块关联的推断）。

15. **API 接口规格**：原始需求未定义任何 API 接口。本文新增第 6 节，列出各功能模块对应的核心 REST 端点、HTTP 方法、认证要求和通用错误响应格式（v3 新增，标注为基于功能描述和 Web 应用通用实践的接口设计）。

16. **doctor_information 表 chat_token 字段**：原始 db.txt 中 chat_token 字段名为"对话Token"但含义不清。本文在数据需求节中补充了其用途（存储 Dify 聊天助手 API Key，格式为 Bearer app-XXX）和前端使用方式（v3 新增）。

17. **life_plans 排序与时段映射**：原始 db.txt 中 order 字段含义笼统。本文在 4.5 节中补充了 order 值到具体时段（早餐=1、午餐=2……）的映射约定，并说明其在前端渲染和打卡分析中的用途（v3 新增）。

18. **危险因素缺失值估算公式**：任务文档中给出了腰围和收缩压的估算逻辑，v2 版本仅统提及"基于 BMI 公式估算"。本文在 4.4 节中补充了完整的估算公式（含按性别区分的系数、BMI 调整因子、收缩压分档查表值），依据来自项目任务5的技术指导文档（v3 新增）。

19. **文章正文存储格式**：本文在 4.6 节和 5 节中明确 articles 表正文字段采用 Markdown 格式存储，前端使用 Markdown 解析器渲染为 HTML，并说明了格式选择的技术理由（v3 新增，标注为基于技术合理性的推断）。

20. **功能验收标准**：v2 版本所有功能模块均为描述性写法，缺乏可验证的完成标准。本文为每个功能模块（4.1-4.9）各增加了 1-2 条可量化的验收标准，覆盖功能完整性、响应时间、必要维度、交互反馈等方面（v3 新增）。

21. **部署架构**：原始需求明确了3台服务器（数据服务器 + 2台系统运行服务器）的硬件规划，以及 Nginx 集群部署的意图，但 v3 文档未展开。本文新增 7.4 节"部署架构"，说明3台服务器的角色分工、Express/SQLite/Nginx 的组件分布、反向代理与负载均衡方案、前端 API 路由路径（v3_rev1 新增，标注为基于服务器规划的架构推断）。

22. **访问控制矩阵**：v3 文档的认证机制（4.10 节）仅从技术层面描述 JWT 校验流程，未在页面/模块层面定义哪些页面可公开访问、哪些需认证。本文在 4.10 节末尾新增"访问控制矩阵"表格，按页面/功能模块逐一标注公开访问、需登录、需 admin 角色的三级权限边界（v3_rev1 新增，标注为基于功能描述的权限推断）。

23. **医学免责声明**：原始需求和 v3 文档均未涉及 AI 生成内容的医学免责声明。本文新增 4.11 节，描述首次使用 AI 功能前的免责确认弹窗、AI 生成内容底部的固定免责提示文案、医师对话界面的免责标识条三项交互设计（v3_rev1 新增，标注为基于医疗健康类应用的合规常识推断）。

24. **风险预测表单交互模式**：v3 文档仅描述"多步骤表单"，未明确前端交互形式。本文在 4.4 节中明确采用分步向导（Step Wizard）模式，用户可自由前进/后退且数据不丢失，并在验收标准中增加对应条目（v3_rev1 新增，标注为基于表单可用性最佳实践的推断）。

25. **健康资讯的用户健康信息数据源**：v3 文档在 4.6 节仅提及"基于用户健康信息"但未说明数据来源。本文补充了三级数据来源优先级（user_risk_info → users 表 → 通用降级）和降级策略（v3_rev1 新增，标注为基于数据表关系的推断）。

26. **Dify 代理端点的请求体参数**：v3 文档的 6.4/6.8/6.10 节仅列出端点路径和功能说明，未定义请求体参数。本文为三个流式代理端点补充了核心参数名称、类型和必填性说明，以及 SSE 代理透传策略（v3_rev1 新增，标注为基于 Dify API 通用规范的参数定义）。

27. **/api/admin/execute 端点的分级鉴权模型**：v4 文档中第 5 节将该端点设计为同时服务管理员和普通用户（经 AI 助手），但第 6.10 节要求 role=admin 鉴权，两处规则矛盾。v5 统一为：端点仅校验 JWT Token 有效性，内部根据 Token.role 分级鉴权——admin 可操作全部数据，user 仅限操作本人数据（通过 Token.user_id 行级约束）。同步更新了第 4.10 节管理员鉴权描述和第 5 节数据路径说明（v5 新增，标注为审查反馈驱动的权限模型修正）。

28. **图片/头像字段的存储策略**：v4 文档定义了多张表的图片字段但未说明上传和管理机制。v5 补充了用户头像（通过新增上传端点管理）、医生头像和糖尿病类型图片（预置静态资源）、文章封面（Dify 工作流外部 URL）的分策略管理方案，新增 6.14 节文件上传端点和 7.4 节 Nginx 静态资源托管路径说明（v5 新增，标注为基于 Web 应用通用实践的存储策略补充）。

29. **AI 内容生成持久化路径**：v4 文档的 Dify 工作流生成内容后写入数据库的流程为隐式约定，v5 将其明确为第三条数据操作路径"AI 内容生成持久化路径"，并为 POST /api/risk/predict、POST /api/plan/generate、POST /api/articles/generate 三个端点补充了完整的服务端处理流程（Dify 响应解析→数据结构化→数据库 INSERT）。Dify 工作流清单汇总表新增"输出→数据库持久化"列（v5 新增，标注为审查反馈驱动的流程澄清）。

30. **系统级 API Key 的环境变量管理**：v4 文档未定义 AI 助手 Agent 和各工作流 API Key 的存储位置。v5 明确系统级 API Key 通过环境变量/.env 管理（区别于医生 chat_token 的数据库存储），给出推荐命名规范，并在 7.5 节列出完整配置清单（v5 新增，标注为基于安全最佳实践的配置管理方案）。

31. **未登录用户点击 FAB 按钮的行为**：v4 文档的访问控制矩阵标注 FAB 入口公开可见但对话需登录，未定义未登录点击行为。v5 在 4.8 节补充：未登录用户点击 FAB 后弹出对话窗口但展示登录引导提示和跳转按钮，而非无响应或展示受限对话（v5 新增，标注为基于交互完整性的推断）。

32. **列表端点的分页参数规范**：v4 文档的 5 个列表 GET 端点未定义分页参数。v5 为 GET /api/doctors、GET /api/punch/list、GET /api/articles、GET /api/assistant/advice、GET /api/admin/logs 统一补充分页查询参数（page、pageSize），并在新增 6.12 节定义统一分页响应格式（v5 新增，标注为基于 API 设计通用实践的分页规范）。

33. **环境配置规范**：v4 文档的敏感配置项（JWT 密钥、Dify API Key 等）分散在各节中，缺少统一的环境配置规范。v5 新增 7.5 节"环境配置"，按 JWT 与安全、Dify API、Express 服务三组列出配置项清单，明确推荐使用 .env 文件管理，敏感信息不得硬编码（v5 新增，标注为基于部署工程实践的配置规范）。

34. **开源发布交付物细化**：v4 文档第 8.3 节仅一句话提及开源发布概念。v5 在 8.3 节末尾逐项列出三项交付物（源代码打包、项目文档、开源仓库地址），与原始 requirement.md 保持一致（v5 新增，标注为与原始需求的对照补充）。

---

## 10. 修订说明（v2 → v3）

本轮修订基于 v2 版本的需求审查报告（`a_v2_iteration_requirement.md`，即组件B诊断报告 b_v1_diag_v1.md 经质询确认结果）中提出的 11 个质量问题，逐一回应如下。其中问题 1-5 在 v1 审查中已被识别、在 v1→v2 修订中未解决，属持续存在的核心缺口；问题 6-11 为本轮审查新发现的问题。

### 10.1 users 表缺少角色字段（审查问题-严重）

**审查意见**：第5节 users 表不含 role 字段，但第4.3节要求登录后根据用户角色展示不同功能入口。数据模型与功能需求直接矛盾。

**修订**：
- 在 5 节 users 表定义中增加 role 字段（TEXT，CHECK(role IN ('user', 'admin'))，默认 'user'）。
- 在 4.3 节中补充角色判定的用途（前端界面显隐控制、后端接口权限校验）和角色设定方式（管理员在后台数据库中直接设定，不提供前端自助变更功能）。
- 在 4.10 节中补充管理员接口的 role=admin 鉴权逻辑。

### 10.2 punch_in 表缺少与 life_plans 的关联字段（审查问题-严重）

**审查意见**：第5节 punch_in 表无 plan_id 外键，打卡分析功能缺乏按方案项进行依从性分析的数据基础。

**修订**：
- 在 5 节 punch_in 表定义中增加 plan_id 字段（INTEGER，FOREIGN KEY REFERENCES life_plans(id)）。
- 在 4.5 节每日打卡描述中补充打卡记录通过 plan_id 关联到具体方案项的说明。
- 在 4.7 节中补充按方案项依从性分析维度的描述，与按类型汇总维度形成互补。

### 10.3 缺少用户认证与会话管理机制（审查问题-高）

**审查意见**：全文未涉及会话保持方式、前端携带身份凭证方式、服务端鉴权方式、密码加密算法选择、iframe 子页面如何共享登录态。

**修订**：
- 新增 4.10 节"用户认证与会话管理"，完整覆盖 JWT 无状态会话机制、Token 生成/存储/传递/校验、前端和服务端鉴权方式、bcrypt 密码哈希存储、iframe 子页面登录态共享。
- 在 6 节 API 接口规格中为每个端点标注认证要求（"是"/"否"/"是 + admin"），并在 6.1 节定义认证相关端点（register/login/logout）。
- 在 6.11 节定义通用错误响应格式，含 AUTH_REQUIRED（401）和 FORBIDDEN（403）错误码。
- 在 7.3 节安全性中补充具体的密码存储和鉴权措施说明。

### 10.4 life_advice 表无对应功能模块（审查问题-高）

**审查意见**：第5节定义了 life_advice 表但全文无任何功能模块使用该表，处于"孤儿"状态。

**修订**：
- 在 4.8 节 AI 智能助手功能描述中增加"获取 AI 生成的健康生活建议"条目，并补充说明该表用于存储 AI 助手在对话中生成的生活建议内容。
- 在 3 节功能模块概览表中更新 AI 智能助手的功能摘要，增加"健康建议生成"。
- 在 5 节 life_advice 表定义中补充"用户可通过 AI 助手对话历史或个人中心入口回溯查看"的说明。
- 标注此功能归属为 AI 智能助手的子功能，不独立成章。

### 10.5 缺少 API 接口规格说明（审查问题-高）

**审查意见**：全文仅有 4.9 节一个具体端点，缺少完整的 Express 端点列表、请求/响应数据结构、错误码定义。

**修订**：
- 新增第 6 节"API 接口规格说明"，按功能模块分组列出核心 REST 端点（共 6.1-6.10 十个小节），含 HTTP 方法、端点路径、功能说明和认证要求。
- 增加 6.11 节定义通用错误响应 JSON 格式和常见错误码（AUTH_REQUIRED、FORBIDDEN、NOT_FOUND、VALIDATION_ERROR、AI_TIMEOUT、INTERNAL_ERROR）。
- 注明完整请求/响应数据结构（JSON Schema）和 Dify 工作流具体参数在概要设计阶段补充。

### 10.6 doctor_information 表的 chat_token 字段含义未解释（审查问题-中）

**审查意见**：第5节定义了"对话 Token"字段，但未说明实际用途和格式。

**修订**：
- 在 5 节 doctor_information 表定义中补充 chat_token 的用途说明：存储对应医生 Dify 聊天助手的 API 访问令牌，格式为 `Bearer app-XXX`，前端在发起医生对话请求时置于 Authorization 请求头中。
- 在 4.2 节医师咨询描述中补充 chat_token 的使用方式（前端通过此 Token 调用 Dify 对话接口）。

### 10.7 life_plans 的排序字段与业务时段概念映射不清（审查问题-中）

**审查意见**：life_plans 表使用 order 字段控制显示顺序，但功能描述使用"早餐、午餐、晚餐"等语义时段概念，数字与时段如何映射未说明。

**修订**：
- 在 4.5 节新增"方案排序与时段映射"段落，明确 order 值与业务时段的映射约定：饮食方案（1=早餐、2=午餐、3=晚餐、4=加餐）；运动方案（1=晨间、2=晚间、3=周末）。
- 说明此映射约定在前端渲染时段分组展示和打卡分析按类型维度统计中的用途。

### 10.8 iframe 架构下的跨模块状态管理未涉及（审查问题-中）

**审查意见**：第1节明确采用 iframe 架构，但未讨论登录态共享、FAB 渲染层级、AI 助手触发导航、iframe 间数据传递等关键问题。

**修订**：
- 新增 1.1 节"iframe 架构下的跨模块通信机制"，覆盖四项通信机制的设计原则：登录态共享（localStorage + postMessage）、FAB 渲染层级（主框架层 + z-index）、AI 助手触发跨模块操作（postMessage 导航指令）、iframe 间数据依赖（主框架中转 / URL 参数 / 共享 localStorage）。
- 注明具体实现方式在架构设计阶段确定。

### 10.9 缺少可量化的功能验收标准（审查问题-中）

**审查意见**：第3-4节所有功能模块均为描述性写法，未定义可验证的完成标准。

**修订**：
- 在 4.1 至 4.9 每个功能模块节末尾各增加"验收标准"子段落，每条标准至少包含一个可量化指标（时间、数量、维度等）。
- 验收标准覆盖：页面布局完整性（4.1）、医生配置数量和首字响应时间（4.2）、角色差异化入口和登录拦截（4.3）、响应时间和表单校验（4.4）、方案项数量和打卡关联可追溯（4.5）、文章生成时间和收藏操作响应（4.6）、分析维度和筛选支持（4.7）、意图覆盖范围和唤起时间（4.8）、CRUD 全流程耗时和操作日志不可删除（4.9）。

### 10.10 危险因素缺失值估算的具体公式未提供（审查问题-低）

**审查意见**：4.4 节仅笼统描述"基于 BMI 公式估算"，未提供具体估算公式。

**修订**：
- 在 4.4 节健康信息采集步骤中补充完整的腰围估算公式（含按性别区分的系数 0.47/0.45 和 BMI 调整因子 0.92/1.00/1.10）和收缩压估算分档值（按性别和 BMI 分层的查表逻辑）。
- 公式来源标注为基于任务文档中技术指导的整理。

### 10.11 文章正文的存储格式未指定（审查问题-低）

**审查意见**：articles 表的"正文"字段未说明存储格式（纯文本/Markdown/HTML），影响 LLM 提示词设计和前端渲染。

**修订**：
- 在 4.6 节文章生成描述中补充正文以 Markdown 格式存储、前端使用 Markdown 解析器渲染的说明，并阐述格式选择的三点技术理由。
- 在 5 节 articles 表定义中将"正文"字段标注为 Markdown 格式的 TEXT 字段。

---

## 11. 修订说明（v3 → v3_rev1）

本轮修订基于 v3 版需求澄清文档的审查报告（`a_v3_iteration_requirement.md`）中提出的 11 个质量问题，逐一回应如下。11 个问题均为 v3 版本引入的新问题（主要源于 v3 新增内容引入的内部不一致和完整性缺口），与 v1→v2 的 5 个问题和 v2→v3 的 11 个问题均不重叠。

### 11.1 密码处理方式前后矛盾（审查问题-阻塞性，问题1）

**审查意见**：第 4.3 节要求"前端经哈希处理后传输"，第 4.10 节推荐"服务端哈希校验"，两处方案互斥。

**修订**：
- 统一为服务端 bcrypt 哈希校验方案。
- 修改第 4.3 节：将"密码在前端经哈希处理后传输至后端"改为"密码通过安全通道传输至服务端，由服务端使用 bcrypt 算法进行哈希存储"。
- 修改第 4.3 节：将"注册信息通过 Text2SQL 工作流写入数据库"改为"注册信息通过 Express 常规 CRUD 接口（POST /api/auth/register）写入数据库"。

### 11.2 数据操作路径存在全局性架构歧义（审查问题-阻塞性，问题2）

**审查意见**：第 5 节末尾声称所有数据库读写经 Dify Text2SQL 工作流，但第 6 节定义了常规 Express CRUD 端点，两条路径边界未区分。

**修订**：
- 重写第 5 节的数据操作路径说明，明确区分两条路径：
  1. 常规 CRUD 路径：标准业务操作通过 Express REST API 直接操作 SQLite。
  2. AI 驱动的 Text2SQL 路径：管理员智能管理操作和 AI 助手部分操作通过 Dify Agent Text2SQL 间接操作数据库。
- 明确两条路径的适用场景和边界：常规 CRUD 用于格式固定、逻辑明确的场景；Text2SQL 用于需灵活查询、无法预定义接口的场景。
- 补充普通用户通过 AI 助手操作的权限约束说明（仅能查询/修改本人数据）。

### 11.3 医师对话 API 存在前端直连与代理转发两种互斥方案（审查问题-高，问题3）

**审查意见**：第 4.2 节描述前端通过 Token 直连 Dify，第 6.4 节推荐 Express 代理端点。

**修订**：
- 选定 Express 代理方案，前端通过 `/api/chat/doctor/:id` 端点调用。
- 修改第 4.2 节：将"前端通过此 Token 调用 Dify 对话接口"改为"前端调用 Express 代理端点，Express 服务端读取 chat_token 后转发请求至 Dify"。
- 修改第 5 节 doctor_information 表定义：chat_token 描述从"前端在发起医生对话请求时置于 Authorization 请求头中"改为"chat_token 仅在服务端 Express 代理层使用，不暴露给前端"。
- 修改第 6.4 节注释：删除"前端根据 chat_token 直接调用 Dify API"的备选描述，明确代理方案为唯一方案。

### 11.4 用户注册的实现路径与 API 定义不一致（审查问题-高，问题4）

**审查意见**：第 4.3 节描述注册经 Text2SQL 工作流，第 6.1 节定义标准 Express 端点。

**修订**：
- 统一为常规 Express CRUD 操作（POST /api/auth/register）。
- 修改第 4.3 节：删除"注册信息通过 Text2SQL 工作流写入数据库"，改为"注册信息通过 Express 常规 CRUD 接口写入数据库"。

### 11.5 认证边界未在页面/模块层面定义（审查问题-高，问题5）

**审查意见**：全文未说明哪些页面需认证、哪些可公开访问。

**修订**：
- 在 4.10 节末尾新增"访问控制矩阵"表格，按页面/功能模块逐一标注三级权限边界：公开访问、需登录（普通用户）、需登录 + admin 角色。
- 表格覆盖全部 15 个页面/功能入口（首页、医师列表/对话、健康资讯浏览/操作、个人中心、风险预测、生活方案、打卡、AI 助手可见/使用、健康建议、智能管理、登录/注册）。
- 补充未登录时的路由守卫行为描述（自动跳转至登录页，登录后回跳）。

### 11.6 缺少部署架构与服务器规划（审查问题-高，问题6）

**审查意见**：原始需求明确给出 3 台服务器规划，但产出未涉及 Nginx 集群、反向代理、负载均衡。

**修订**：
- 新增 7.4 节"部署架构"，完整描述 3 台服务器的角色分工：服务器1（数据服务器：SQLite + Express + Nginx 静态文件）、服务器2和服务器3（系统运行服务器：Nginx 反向代理 + 负载均衡集群）。
- 补充前端部署方式（Nginx 静态文件托管）、API 路由路径（用户 → Nginx → Express）、负载均衡方案选项（DNS 轮询或 Keepalived 主备）。
- 说明 Dify 和 DeepSeek 为外部云服务依赖。

### 11.7 健康资讯生成依赖的用户健康信息未明确来源与降级策略（审查问题-中，问题7）

**审查意见**：第 4.6 节未说明"用户健康信息"的数据来源字段，以及无健康数据时的降级策略。

**修订**：
- 在 4.6 节"分类生成"描述中补充三级数据来源优先级：（1）优先取 user_risk_info 表最新记录的年龄/性别/BMI/家族史/糖尿病类型；（2）降级取 users 表注册信息；（3）若无有效数据，降级为通用分类模式（不依赖个人数据）。
- 标注此补充为基于数据表关系的推断。

### 11.8 AI 助手"健康建议"入口与导航结构脱节（审查问题-中，问题8）

**审查意见**：第 4.8 节提到"健康建议"入口，但第 4.1 节导航结构和第 4.3 节个人中心入口列表均未包含。

**修订**：
- 在 4.3 节个人中心入口列表中新增"健康建议（查看 AI 助手生成的历史健康生活建议列表）"。
- 在 4.1 节导航映射表中更新"我的"Tab 的子页面列表，从"糖尿病风险预测、打卡记录与分析"改为"糖尿病风险预测、打卡记录与分析、健康建议"。

### 11.9 Dify 代理端点的请求体参数格式未定义（审查问题-中，问题9）

**审查意见**：第 6.4/6.8/6.10 节流式代理端点的请求体参数和 SSE 代理转发策略未说明。

**修订**：
- 为 6.4 节医师对话端点补充请求体参数表（message、conversation_id）和 SSE 代理转发策略说明（流模式透传，fetch + ReadableStream 消费）。
- 为 6.8 节 AI 助手端点补充请求体参数表（message、conversation_id）和 SSE 代理转发策略。
- 为 6.10 节 Dify 代理接口补充通用请求体参数表（inputs/query、conversation_id、user、response_mode）和 SSE 代理转发策略。

### 11.10 风险预测表单步骤数未明确（审查问题-低，问题10）

**审查意见**：第 4.4 节未说明前端采用分步向导还是单页表单。

**修订**：
- 在 4.4 节明确前端采用分步向导（Step Wizard）交互模式，补充描述"每一步聚焦一组相关字段，进度指示器显示当前所处步骤，用户可自由前进/后退修改已填写内容，已填写数据不会因步骤切换而丢失"。
- 在验收标准中新增"用户可通过进度指示器在步骤间自由前进/后退，已填写数据不会因步骤切换而丢失"条目。

### 11.11 缺少医学免责声明功能描述（审查问题-低，问题11）

**审查意见**：全文未描述 AI 生成内容的免责声明界面元素和交互逻辑。

**修订**：
- 新增 4.11 节"医学免责声明"，完整描述三项免责交互设计：
  1. 首次使用 AI 功能前的免责确认弹窗（含确认/暂不使用按钮，localStorage 持久化确认状态）。
  2. AI 生成内容底部的固定免责提示文案（灰色小字、浅色背景条，覆盖所有 AI 输出页面）。
  3. 医师对话界面的持续免责标识条（半透明背景条，对话全程可见）。
- 标注此补充为基于医疗健康类应用合规常识的推断。

---

## 12. 修订说明（v3_rev1 → v4）

本轮修订基于 v3_rev1 版需求澄清文档的审查报告（`a_v4_iteration_requirement.md`）中提出的 7 个质量问题，逐一回应如下。其中问题 1 为迭代第2轮修复遗漏的残余问题（第4.10节密码处理矛盾未完全同步），问题 2-7 为本轮审查新发现的问题。

### 12.1 第4.10节认证流程残余矛盾修复（审查问题-严重，问题1）

**审查意见**：第 4.10 节"认证流程"段落的正文同时描述两种互斥的密码处理方案（前端 bcrypt 哈希 + 括号内推荐服务端哈希），与第 4.3 节已统一的服务端哈希方案矛盾。此问题在 v3→v3_rev1 修订（11.1 节）中已被识别，但修订仅修改了 4.3 节而未同步修改 4.10 节，属修订遗漏。

**修订**：
- 将第 4.10 节"认证流程"段落首句修改为与 4.3 节一致的表述，删除括号内的备选方案描述。修改后的认证流程为：密码通过 HTTPS 安全通道传输至服务端，由服务端使用 bcrypt 算法进行哈希校验。

### 12.2 新增系统初始数据种子方案（审查问题-一般，问题2）

**审查意见**：系统启动后依赖医生信息、糖尿病类型科普内容、管理员账号、科普文章四类预置数据才能正常运行，但文档未定义这些数据的初始化方式。chat_token 的获取时机、管理员账号的预置方式、科普文章的示例内容均未说明。

**修订**：
- 在第 5 节末尾新增"初始数据要求"段落，明确四类预置数据的初始化方式和内容要求：（1）至少 3 位不同科室医生记录的预填充及 chat_token 在 Dify 平台创建应用后获取；（2）diabetes_types 表需预填充 4 类糖尿病类型及其病因、表现、治疗方式；（3）管理员账号通过 SQL 初始化脚本直接插入，含 bcrypt 哈希后的默认密码，首次登录后强制修改；（4）建议预置 2-3 篇示例科普文章。推荐使用数据库初始化 SQL 脚本执行，确保部署可复现。

### 12.3 新增糖尿病类型科普 API 端点（审查问题-一般，问题3）

**审查意见**：第 4.1 节将"糖尿病类型科普入口"列为首页功能，第 5 节定义了 diabetes_types 表，但第 6 节未定义任何读取糖尿病类型数据的 API 端点。diabetes_types 是唯一有数据表定义但无 API 端点的实体。

**修订**：
- 在第 6 节新增 6.8"糖尿病类型相关"子节，定义两个公开访问端点：（1）GET /api/diabetes-types — 获取所有糖尿病类型列表；（2）GET /api/diabetes-types/:id — 获取单个类型详细信息。与医生列表端点一致，设为无需认证即可访问。原 6.8-6.11 节顺延重编号为 6.9-6.12。

### 12.4 新增 Dify 工作流清单汇总表（审查问题-一般，问题4）

**审查意见**：全文在多处提及需要创建的 Dify 工作流/Agent（风险预测、方案生成、资讯生成、打卡分析、AI 助手 Agent、管理员 Agent、医师聊天助手），但 6.10 节仅提供通用代理端点模板，未列出完整工作流清单及其核心 inputs 变量。各工作流的 inputs 定义分散在功能章节中，部分工作流（如打卡分析）未提及任何 inputs 字段。

**修订**：
- 在 6.11 节（原 6.10 节）末尾新增"Dify 工作流清单汇总"表格，列出全部 7 个工作流/Agent/聊天助手的：工作流标识（推荐命名）、类型（工作流/Agent/聊天助手）、用途、所属功能模块、触发端点、核心 inputs 变量列表。每个 inputs 变量标注已在对应功能章节详细定义。补充了打卡分析工作流的 inputs 字段（user_id、date_range）。Agent 的工具链配置留待概要设计阶段补充。

### 12.5 补充 AI 服务降级行为规范（审查问题-一般，问题5）

**审查意见**：第 7.3 节"健壮性"仅有一句笼统要求，未说明任何具体降级行为。考虑到平台几乎所有核心功能均依赖外部 AI 服务，以下场景缺少规范：AI 服务完全不可用时的展示内容、响应超时时的重试策略、不同 AI 功能的差异化降级策略、部分功能可用部分不可用时的处理方式。

**修订**：
- 在第 7.3 节"健壮性"条目下补充四项具体降级规范：（1）AI 服务完全不可用时展示统一错误状态组件（含友好提示文案和手动重试按钮）；（2）超时阈值统一为 15 秒，超时后展示提示并允许手动重试，不自动重试；（3）有历史缓存数据时优先展示缓存内容并标注"上次生成时间"；（4）流式接口 SSE 连接中断时展示"连接中断，点击重试"提示条，保留已接收内容不丢失。

### 12.6 新增对话会话生命周期管理（审查问题-轻微，问题6）

**审查意见**：第 6.4 节和第 6.8 节将 conversation_id 定义为可选请求参数，但以下生命周期操作缺少定义：前端如何获取已有会话列表、用户如何恢复历史对话、新建会话的触发方式、会话是否有过期或自动清理机制。

**修订**：
- 在第 4.2 节（医师咨询）和第 4.8 节（AI 智能助手）各新增"会话管理"段落，明确：（1）进入对话界面时默认创建新会话（不传 conversation_id），Dify 返回新 ID 后前端保存至 localStorage；（2）前端在 localStorage 中维护当前活跃对话的 conversation_id；（3）历史对话列表通过新增 GET 端点获取（/api/chat/doctor/:id/conversations 和 /api/assistant/conversations）；（4）会话不设置自动过期，由用户在 UI 中手动删除。
- 在第 6.4 节医师咨询 API 表中新增 GET /api/chat/doctor/:id/conversations 端点，在第 6.9 节 AI 助手 API 表中新增 GET /api/assistant/conversations 端点。

### 12.7 补充用户密码强度要求（审查问题-轻微，问题7）

**审查意见**：全文未定义密码的最小长度、复杂度要求以及前后端校验规则，导致前端注册表单的实时校验规则无法确定、后端注册接口的参数校验门槛不一致。

**修订**：
- 在第 4.3 节注册描述中补充密码要求："密码长度不少于 8 位，需包含字母和数字"，并明确前后端均需按此规则进行校验（前端注册表单实时校验，后端注册接口参数校验）。

### 本轮的跨节结构性变更

本轮修订涉及以下跨节的结构性调整，在阅读文档时需注意章节编号的变更：

- **第 6 节重新编号**：因新增 6.8"糖尿病类型相关"子节，原 6.8-6.11 节顺延重编号为 6.9-6.12。涉及内部交叉引用处（如 6.4 节 SSE 代理转发策略的引用、6.9 节与 6.4 节一致的说明）已同步更新。
- **第 5 节新增 5.1 小节**：新增"新增 API 端点对应的数据操作"小节作为索引，指向第 6 节对应接口规格。

---

## 13. 修订说明（v4 → v5）

本轮修订基于 v4 版需求澄清文档的审查报告（`a_v5_iteration_requirement.md`）中提出的 8 个质量问题，逐一回应如下。8 个问题均为第 4 轮审查新发现的问题，与 v1→v2（5 个）、v2→v3（11 个）、v3→v3_rev1（11 个）、v3_rev1→v4（7 个）的问题均不重叠。

### 13.1 /api/admin/execute 端点权限模型矛盾修复（审查问题-严重，问题1）

**审查意见**：第 5 节将 `/api/admin/execute` 设计为同时服务管理员和普通用户（经 AI 助手）的 Text2SQL 执行入口，但第 6.10 节要求 role=admin 鉴权。两条规则互斥——若执行 6.10 节鉴权逻辑，普通用户通过 AI 助手触发的 Text2SQL 操作将收到 403。

**修订**（采用推荐方案 A）：
- 将 `/api/admin/execute` 的认证要求从"是 + admin"修改为"是"（JWT 认证即可，不强制 role=admin），Express 端点内部根据 Token.role 进行分级鉴权：admin 可执行任意 SQL 操作，user 仅限操作与当前用户本人相关的数据（通过 Token.user_id 行级约束）。
- 同步更新第 4.10 节"管理员鉴权"描述、第 5 节 Text2SQL 数据路径说明和第 6.10 节管理相关 API 表。

### 13.2 新增图片/头像上传与管理机制（审查问题-一般，问题2）

**审查意见**：users 表、doctor_information 表、diabetes_types 表、articles 表均定义了图片相关字段，但全文未定义任何图片上传 API 端点、存储策略或文件类型/大小限制。

**修订**：
- 在第 5 节新增"图片/头像字段的存储策略"段落，按四种场景定义分策略：用户头像（上传端点管理，本地存储）、医生头像（预置静态资源）、糖尿病类型图片（预置静态资源）、文章封面（Dify 工作流外部 URL）。
- 新增 6.14 节"文件上传"，定义 POST /api/upload/avatar 端点及其服务端处理流程。
- 在 7.4 节补充 Nginx 静态资源托管路径说明（含 `/static/uploads/avatars/`、`/static/images/doctors/`、`/static/images/diabetes/` 三个目录）。

### 13.3 新增 AI 内容生成持久化路径（审查问题-一般，问题3）

**审查意见**：POST /api/risk/predict、POST /api/plan/generate、POST /api/articles/generate 三个端点触发 Dify 工作流生成内容后，写入数据库的流程从未被明确描述，属于未命名的第三条路径。

**修订**：
- 在第 5 节新增第 3 条数据操作路径"AI 内容生成持久化路径"，定义其基本流程（Dify 响应解析→数据结构化→数据库 INSERT/UPDATE）。
- 在 6.3、6.5、6.7 节分别为三个 POST 端点补充服务端处理流程简述。
- 在 6.11 节 Dify 工作流清单汇总表中新增"输出→数据库持久化"列。

### 13.4 补充系统级 API Key 的环境变量管理方案（审查问题-一般，问题4）

**审查意见**：AI 助手 Agent 和管理员 Agent 及各工作流的 API Key 存储位置完全未提及。这些 API Key 不属于用户级数据，无法沿用数据库存储模式。

**修订**：
- 在第 5 节新增"系统级 API Key 管理"段落，明确系统级 API Key 通过环境变量/.env 配置文件管理，区别于医生 chat_token 的数据库存储模式。给出推荐命名规范（DIFY_ASSISTANT_API_KEY 等）。
- 在 7.5 节"环境配置"中列出完整的 Dify API 配置表。

### 13.5 补充未登录用户点击 FAB 按钮的行为定义（审查问题-轻微，问题5）

**审查意见**：第 4.8 节描述 FAB 全局可见，第 4.10 节访问控制矩阵标注 FAB 入口公开但对话需登录，未登录用户点击 FAB 后应发生什么未定义。

**修订**：
- 在 4.8 节新增"未登录用户点击 FAB 的行为"段落，明确：未登录用户点击 FAB 后弹出对话窗口，但窗口内展示登录引导提示和跳转按钮，不展示对话输入区域。

### 13.6 补充列表类 GET 端点的分页参数规范（审查问题-轻微，问题6）

**审查意见**：5 个返回列表数据的 GET 端点均未定义分页参数。

**修订**：
- 为 GET /api/doctors、GET /api/punch/list、GET /api/articles、GET /api/assistant/advice、GET /api/admin/logs 五个端点统一补充分页查询参数（page 和 pageSize，默认 page=1、pageSize=20，最大 100）。
- 新增 6.12 节"分页响应格式"，定义统一的 data+pagination 响应结构。
- 原 6.12 节"通用错误响应格式"顺延重编号为 6.13 节。

### 13.7 新增环境配置规范（审查问题-轻微，问题7）

**审查意见**：文档多处引用了需在部署时配置的敏感信息，但全文未定义统一的环境配置方式。

**修订**：
- 新增 7.5 节"环境配置"，按 JWT 与安全、Dify API、Express 服务三组列出关键配置项清单（含配置项名称、说明和示例值），推荐使用 .env 文件管理敏感配置，明确不得硬编码或提交至版本控制系统。

### 13.8 细化开源发布交付物清单（审查问题-轻微，问题8）

**审查意见**：原始 requirement.md 明确列出三项交付物，但 SRS 第 8.3 节仅一句话提及开源发布概念。

**修订**：
- 在第 8.3 节末尾逐项列出三项交付物：源代码打包、项目文档、开源仓库地址，与原始需求保持一致。

### 本轮的跨节结构性变更

本轮修订涉及以下跨节的结构性调整：

- **第 6 节重新编号**：因新增 6.12"分页响应格式"和 6.14"文件上传"子节，原 6.12"通用错误响应格式"顺延重编号为 6.13。
- **第 5 节数据路径从两条扩展为三条**：新增第 3 条"AI 内容生成持久化路径"，原"两条路径"相关表述同步更新为"三条路径"。
- **第 7 节新增 7.5 小节**：新增"环境配置"，集中管理全文分散的敏感配置项。
- **第 6 节 Dify 工作流清单汇总表新增列**：新增"输出→数据库持久化"列。
- **第 5 节新增三个段落**：图片/头像存储策略、系统级 API Key 管理、AI 内容生成持久化路径。
- **第 4.8 节新增段落**：未登录用户点击 FAB 的行为。
- **第 8.3 节补充内容**：开源发布三项交付物清单。

---

## 14. 修订说明（v5 → v5_rev2）

本轮修订基于 v5 版需求澄清文档的审查报告（`a_v5_review_v1.md`）中提出的 2 个质量问题，逐一回应如下。2 个问题均为第 5 轮审查新发现的问题，与 v1→v2（5 个）、v2→v3（11 个）、v3→v3_rev1（11 个）、v3_rev1→v4（7 个）、v4→v5（8 个）的问题均不重叠。

### 14.1 第 5 节数据路径数量前导句矛盾修复（审查问题-一般，问题1）

**审查意见**：第 5 节开篇声明"平台存在**两条**数据操作路径"，但随后列出三条路径（常规 CRUD、AI 驱动 Text2SQL、AI 内容生成持久化）。同节末尾使用"三条路径"的正确表述。这是 v4→v5 修订从两条路径扩展为三条后未同步修改前导句的遗留错误。

**修订**：
- 将第 5 节第 297 行"平台存在两条数据操作路径"修改为"平台存在三条数据操作路径"，与后续实际列出的三条路径及第 303 行"三条路径"的表述保持一致。

### 14.2 Dify Agent 回调 `/api/admin/execute` 的用户身份传递机制补充（审查问题-一般，问题2）

**审查意见**：Dify Agent 通过 Text2SQL 工具回调 `/api/admin/execute` 时，HTTP 请求来自 Dify 服务器而非用户浏览器，用户浏览器的 JWT Token 无法传递到此回调路径。当前文档假设通过 JWT Token.user_id 进行行级权限约束，但 Dify Agent 回调场景下此假设不成立——要么行级权限约束无法实际执行（安全风险），要么下游架构师在设计阶段才发现需要补充认证桥接机制（返工风险）。

**修订**（采用方案 a——双认证模式）：
- 在第 5 节 Text2SQL 路径描述后新增"**Dify Agent 回调 `/api/admin/execute` 时的用户身份传递机制**"段落，定义双认证模式：浏览器直连场景使用 JWT Token（原有机制不变）；Dify Agent 回调场景使用系统级 API Key（`DIFY_SERVICE_API_KEY`）验证请求来源，并在请求体中携带 user_id 参数（由 Dify Agent 从对话上下文中获取——Express 代理转发时通过 Dify 的 `user` 参数传入当前用户 ID，Dify Agent 在 Text2SQL 工具调用时将其填入回调请求体）。双认证模式的具体实现细节在概要设计阶段定义。
- 同步更新第 4.10 节"管理员鉴权"描述，明确 `/api/admin/execute` 端点采用双认证模式，分别说明浏览器直连和 Dify Agent 回调两种场景的鉴权路径。
- 同步更新第 6.10 节 `/api/admin/execute` 端点说明，补充双认证模式描述和对应的认证要求（浏览器直连为 JWT，Dify 回调为 API Key）。
- 在 7.5 节 Dify API 配置表中新增 `DIFY_SERVICE_API_KEY` 配置项，用于 Dify Agent 回调时的服务间认证。

### 本轮的跨节结构性变更

本轮修订涉及以下跨节的结构性调整：

- **第 5 节新增段落**："Dify Agent 回调 `/api/admin/execute` 时的用户身份传递机制"。
- **第 4.10 节重写"管理员鉴权"段落**：从单一 JWT 鉴权模式扩展为双认证模式描述。
- **第 6.10 节更新 `/api/admin/execute` 端点说明**：认证要求列从单一"是"扩展为"是（浏览器直连）/ API Key（Dify 回调）"。
- **第 7.5 节 Dify API 配置表新增行**：`DIFY_SERVICE_API_KEY`。

---

## 15. 修订说明（v5_rev2 → v6）

本轮修订基于 v5_rev2 版需求澄清文档的审查报告（`a_v6_iteration_requirement.md`）中提出的 11 个质量问题，从实现者视角逐一回应如下。其中 5 个问题（问题 1-5）为第 5 轮和第 6 轮审查中持续存在的跨轮核心短板；6 个问题（问题 6-11）为本轮审查新发现的问题。

### 15.1 补充三个核心 AI POST 端点的请求体参数定义（审查问题-严重，第6轮问题1）

**审查意见**：POST /api/risk/predict、POST /api/plan/generate、POST /api/articles/generate 三个核心 AI 端点的请求体 JSON 字段名、类型、是否必填从未给出，实现者无法确定前端应向这些端点发送什么结构的 JSON 数据。

**修订**：
- 在 6.3 节为 POST /api/risk/predict 新增请求体参数表，列出 10 个字段（diabetes_history、diabetes_type、age、gender、height、weight、waist、systolic_bp、family_history、pregnancy），含类型、必填性和说明。可选字段标注估算公式参考位置。
- 在 6.5 节为 POST /api/plan/generate 新增请求体参数表，列出 health_info（object）和 preferences（object）两个顶层字段，标注内部子字段待概要设计阶段补充。
- 在 6.7 节为 POST /api/articles/generate 新增请求体参数表，列出 category 字段（可选，不传时进入分类生成阶段）。
- 在 6.6 节为 POST /api/punch 新增请求体参数表，列出 plan_id、punch_type、completion_status、remarks 四个字段。

### 15.2 修正 EventSource API 的技术使用推荐错误（审查问题-严重，第6轮问题2）

**审查意见**：6.4 节和 6.9 节推荐使用 EventSource API 消费 SSE 流，但 EventSource 不支持自定义 HTTP 头，无法携带 JWT Token 以通过认证。

**修订**：
- 在 6.4 节 SSE 代理转发策略中删除 EventSource API 选项，明确推荐仅使用 fetch + ReadableStream 方式消费流数据，并补充技术原因说明（EventSource 不支持自定义请求头，无法携带 Authorization: Bearer \<token\>）。
- 在 6.9 节 SSE 代理转发策略中同步更新，删除"与 6.4 节一致"的模糊措辞，明确 fetch + ReadableStream 为唯一推荐方案并说明原因。

### 15.3 补充三个 PUT 端点的请求体参数定义（审查问题-一般，第6轮问题3）

**审查意见**：PUT /api/plan/adjust、PUT /api/user/profile、PUT /api/user/password 三个端点的请求体参数均未定义。

**修订**：
- 在 6.5 节为 PUT /api/plan/adjust 新增请求体参数表，列出 plan_id（待调整方案ID）和 feedback（自然语言修改意见）两个字段。
- 在 6.2 节为 PUT /api/user/profile 新增请求体参数表，列出 username 和 avatar 两个可选字段，并说明头像字段与 POST /api/upload/avatar 的协作流程（先上传获取路径，再将路径提交至本端点）。
- 在 6.2 节为 PUT /api/user/password 新增请求体参数表，列出 old_password 和 new_password 两个必填字段，new_password 须满足密码复杂度要求。

### 15.4 为两个遗漏的列表端点补充分页参数（审查问题-一般，第6轮问题4）

**审查意见**：v5_rev2 为 5 个列表端点统一补充分页参数，但遗漏了 GET /api/risk/history 和 GET /api/articles/collections 两个端点。

**修订**：
- 在 6.3 节为 GET /api/risk/history 补充分页查询参数（page、pageSize）。
- 在 6.7 节为 GET /api/articles/collections 补充分页查询参数（page、pageSize）。

### 15.5 澄清多医师场景下 conversation_id 的存储键管理模型（审查问题-一般，第6轮问题5）

**审查意见**：文档描述 localStorage 中维护"当前活跃对话的 conversation_id"（单数），但平台至少配置 3 位医生，每位医生拥有独立的 Dify 对话空间。存在存储键冲突和切换后上下文丢失两个歧义。

**修订**：
- 在 4.2 节"会话管理"段落中明确 localStorage 按医生 ID 区分存储键（`conversation_doctor_{id}`），使得每位医生的对话上下文独立保持，切换医生后原对话上下文不丢失。
- 将 4.2 节和 4.8 节中的"建议新增"措辞统一修改为"系统需提供"，与第 6 节 API 表中已确定的端点定义保持一致（回应第 6 轮问题 8）。

### 15.6 补充 POST /api/auth/login 和 POST /api/auth/register 的请求体参数（审查问题-轻微，第6轮问题6）

**审查意见**：POST /api/auth/login 是用户登录的核心端点，但请求体参数（username、password）从未显式列出。

**修订**：
- 在 6.1 节为 POST /api/auth/register 新增请求体参数表，列出 username 和 password 两个字段（password 含复杂度校验说明）。
- 在 6.1 节为 POST /api/auth/login 新增请求体参数表，列出 username 和 password 两个字段。

### 15.7 在 POST /api/punch 中补充"备注"字段（审查问题-轻微，第6轮问题7）

**审查意见**：POST /api/punch 的描述遗漏了备注字段，但第 5 节 punch_in 表的定义包含该字段，实现者无法判断前端是否需要提供输入入口。

**修订**：
- 在 6.6 节 POST /api/punch 端点描述中补充"备注"二字。
- 在 6.6 节 POST /api/punch 的请求体参数表中列出 remarks 字段（string，可选），说明用于用户记录打卡当天的感受和特殊情况。

### 15.8 修正"建议新增"措辞与 API 表的矛盾（审查问题-轻微，第6轮问题8）

**审查意见**：第 4.2 节和第 4.8 节使用"建议新增"这一建议性措辞，但第 6.4 节和第 6.9 节 API 表中已列出对应端点，功能描述中的"建议"与 API 表中的确定存在形成矛盾。

**修订**：
- 将 4.2 节"会话管理"段落中的"建议新增"修改为"系统需提供"。
- 将 4.8 节"会话管理"段落中的"建议新增"修改为"系统需提供"。
- 两处修改已与 15.5 节修订合并执行。

### 15.9 补充 SQLite 单实例数据可靠性说明（审查问题-轻微，第6轮问题9）

**审查意见**：部署架构使用 3 台服务器，但 SQLite 为文件型数据库仅存在于服务器 1 上。若服务器 1 宕机，3 台服务器在数据可用性上等同于 1 台，与第 7.3 节可靠性承诺矛盾。

**修订**：
- 在 7.4 节末尾新增"SQLite 数据可靠性说明"段落，明确指出 SQLite 为单实例文件数据库，不具备主从复制或自动故障转移能力。服务器 1 宕机时 API 服务和数据访问将全部中断。建议建立数据库文件的定期备份策略以降低数据丢失风险。

### 15.10 说明 life_advice 无需单独详情端点的设计意图（审查问题-轻微，第6轮问题10）

**审查意见**：健康资讯模块（articles）提供了完整的列表+详情端点对，但健康建议模块（life_advice）仅定义了列表端点，缺少单个建议详情端点。

**修订**：
- 在 6.9 节 GET /api/assistant/advice 端点说明中增加"列表中每条记录已包含标题、标签、完整内容字段，无需独立的详情端点"，使设计意图明确。

### 15.11 删除 5.1 节空壳占位节（审查问题-轻微，第6轮问题11）

**审查意见**：第 5.1 节内容仅为一句话指向第 6 节的索引语句，不含任何实质性内容，作为独立小节的标题暗示有实质内容但实际上只是一个跳转指令。

**修订**：
- 删除 5.1 节编号和标题，将其内容合并到第 5 节导言段落的末尾（"本章涉及的数据表对应的新增 API 端点的完整接口规格见第 6 节"），消除空壳小节。

### 本轮的跨节结构性变更

本轮修订涉及以下跨节的结构性调整：

- **第 5.1 节删除**：原 5.1"新增 API 端点对应的数据操作"空壳节的编号和标题已删除，内容合并至第 5 节末尾导言段落。
- **第 6 节多处新增请求体参数表**：6.1（auth/login、auth/register）、6.2（user/profile、user/password）、6.3（risk/predict、punch）、6.5（plan/generate、plan/adjust）、6.6（punch）、6.7（articles/generate）共 11 个端点的请求体参数表为本轮新增。
- **第 6.3 节和第 6.7 节 GET 端点补充分页参数**：GET /api/risk/history 和 GET /api/articles/collections 新增 page/pageSize 查询参数。
- **第 6.4 节和第 6.9 节 SSE 策略修正**：删除 EventSource API 推荐，统一为 fetch + ReadableStream，并补充技术原因说明。
- **第 7.4 节新增段落**："SQLite 数据可靠性说明"。
- **第 4.2 节会话管理段落改写**：明确 localStorage 按医生 ID 区分存储键，并修正"建议新增"措辞。

---

## 16. 修订说明（v6 → v7）

本轮修订基于 v6 版需求澄清文档的审查报告（`a_v7_iteration_requirement.md`）中提出的 14 个质量问题，从实现者"能否直接开工编码"的视角逐一回应如下。14 个问题均为第 7 轮审查新发现的问题，与 v1→v2（5 个）、v2→v3（11 个）、v3→v3_rev1（11 个）、v3_rev1→v4（7 个）、v4→v5（8 个）、v5→v5_rev2（2 个）、v5_rev2→v6（11 个）的问题均不重叠。

### 16.1 管理员智能管理功能缺少用户对话端点（审查问题-严重，问题1）

**审查意见**：第 4.9 节描述管理员通过自然语言对话界面操作数据库，但第 6 节 API 接口规格中管理员与 admin-manager-agent 之间的用户对话端点完全缺失。对比 AI 智能助手模块（`POST /api/assistant/chat` 与 `POST /api/dify/agent/:agent_id` 明确分离），管理员模块缺少等价端点。

**修订**：
- 在第 6.10 节管理相关 API 表中新增 `POST /api/admin/chat` 端点（SSE 流式响应，认证要求为"是+admin"），请求体参数至少包含 message（string，必填）和 conversation_id（string，可选）。
- 补充 `/api/admin/chat` 的 SSE 代理转发策略说明和 SSE 流内错误事件处理策略引用。
- 同步更新 `/api/admin/execute` 端点说明，标注浏览器直连场景已由 `/api/admin/chat` 替代，`/api/admin/execute` 主要服务于 Dify Agent 回调场景。

### 16.2 life_advice 表的写入机制不完整（审查问题-严重，问题2）

**审查意见**：第 4.8 节描述 AI 助手可生成健康生活建议并存储于 life_advice 表，但全文未定义 Agent 通过哪个端点写入 life_advice 表。对比 health-article-generator 工作流（明确的"AI 内容生成持久化路径"），life_advice 的写入路径仅有箭头标注但缺乏可执行流程。

**修订**：
- 在第 5 节"AI 内容生成持久化路径"段落中新增 life_advice 表的写入说明段落，明确其写入路径（用户对话消息 → Express 代理转发至 Dify Agent → Agent 判断需生成健康建议 → Text2SQL 工具回调 `/api/admin/execute` → Express 执行 INSERT 写入 life_advice 表），纳入 AI 内容生成持久化路径的覆盖范围。
- 在第 6.9 节新增"life_advice 表的写入路径说明"段落，阐明 life_advice 表不存在独立的 CRUD POST 端点，其写入完全由 Agent 在对话中通过 Text2SQL 工具自主触发。

### 16.3 Dify Agent Text2SQL 工具回调中 user_id 动态传递的可行性未经验证（审查问题-一般，问题3）

**审查意见**：文档假设 Dify 平台支持在工具回调请求体中引用对话上下文的 user 参数，但未提供验证依据。

**修订**：
- 在第 5 节双认证模式描述后新增"Dify 平台能力验证任务"段落，明确在开发环境搭建阶段增加前置验证任务——实测 Dify 平台是否支持在工具回调请求体模板中引用 `{{user}}` 变量。
- 补充备选方案：若 Dify 平台不支持，采用 Express 服务端 session_id → user_id 映射表方案（Express 生成唯一 session_id 关联 user_id，Dify Agent 回调携带 session_id，Express 反查 user_id）。

### 16.4 POST /api/admin/execute 在 Dify Agent 回调场景下的请求体格式未定义（审查问题-一般，问题4）

**审查意见**：第 5 节和第 6.10 节仅从概念层面描述双认证模式，但 JSON 结构从未给出。

**修订**：
- 在第 6.10 节为 `/api/admin/execute` 新增两组请求体参数表：（1）Dify Agent 回调场景——含 sql（string，必填）、user_id（string，必填）、api_key（string，必填）三个字段；（2）浏览器直连场景（保留兼容）——含 sql（string，必填）一个字段。
- 说明参数名需与 Dify 平台上 Agent 的 Text2SQL 工具回调请求体模板保持一致。

### 16.5 iframe 间 postMessage 通信协议未定义（审查问题-一般，问题5）

**审查意见**：第 1.1 节描述了四种跨模块通信场景，但全文未定义任何具体消息格式。

**修订**：
- 在第 1.1 节末尾新增"postMessage 消息协议规范"段落，定义 AUTH_SYNC、NAVIGATE、DATA_TRANSFER 三种核心消息类型的标准格式（type + payload 结构）、方向和用途表格。
- 明确消息接收方必须校验 event.origin（仅接受同源消息），以及 iframe 生命周期中的消息监听器注册/移除要求。

### 16.6 SSE 流内 Dify 错误事件的客户端处理策略未定义（审查问题-一般，问题6）

**审查意见**：第 7.3 节的"SSE 连接中断"处理仅覆盖网络层面，不覆盖流内逻辑错误事件。

**修订**：
- 在第 6.4 节 SSE 代理转发策略后新增"SSE 流内错误事件处理"段落，定义前端按 event 字段区分错误类型（工具调用失败、知识库检索异常、安全审核拦截等）并分类处理的策略。
- 明确流内错误不影响已接收消息内容、错误信息展示为警告气泡的 UI 约定。

### 16.7 前端 SPA 路由结构完全未定义（审查问题-一般，问题7）

**审查意见**：文档明确采用 SPA 架构但未定义任何 URL 路由结构。

**修订**：
- 新增第 1.2 节"前端路由结构"，覆盖路由方案选型（hash 路由优先，history 路由备选）、各模块 URL 路径映射表（12 条路由）、路由守卫逻辑（Token 有效性校验 + 自动跳转登录）、iframe 子页面 URL 规范（查询参数传递内部子路由）。

### 16.8 JWT Token 过期时的前端行为未定义（审查问题-一般，问题8）

**审查意见**：第 4.10 节定义了 JWT 过期时间为 24 小时，但 Token 在操作过程中过期时的前端行为未定义。

**修订**：
- 在第 4.10 节新增"Token 过期处理"段落，定义四种过期场景的处理策略：前端 HTTP 拦截器统一处理 401（清除 Token + 广播登出 + 非阻断提示 + 登录回跳）、SSE 对话中过期（已接收消息不丢失）、多步骤表单中途过期（sessionStorage 数据保留）、iframe 间 Token 过期同步。

### 16.9 Express 端请求体字段名与 Dify API 参数名的映射关系未注明（审查问题-一般，问题9）

**审查意见**：多个端点的请求体字段名（如 `message`）与底层 Dify API 参数名（如 `query`）不同，但映射关系从未被标注。

**修订**：
- 在第 6 节导言部分新增"请求参数映射说明"段落，以表格形式列出关键参数名映射关系（message → query、conversation_id → conversation_id、业务字段 → inputs.{field_name}），并说明 Express 代理层的映射职责。

### 16.10 页面/模块级别的交互状态未按模块系统定义（审查问题-一般，问题10）

**审查意见**：第 4.1-4.9 节定义了核心交互流程但各模块的中间交互状态未在模块层面系统定义。

**修订**：
- 在第 7.1 节新增"交互状态规范"段落，统一定义加载中（页面级骨架屏、组件级按钮禁用 + 进行时文本、AI 生成阶段描述 + 进度条）、空数据（列表类空状态插图 + 引导按钮、生成类功能引导页、对话类欢迎语 + 推荐话题）、错误（网络错误重试组件、数据校验字段级错误提示、权限错误提示页）三类中间状态的展示标准。

### 16.11 视觉设计系统基础规范未定义（审查问题-一般，问题11）

**审查意见**：第 7.1 节以原则性描述为主，缺少具体设计参数，前端开发者无法开始编写 CSS。

**修订**：
- 在第 7.1 节新增"设计系统基础参数"子节，定义品牌主色调色值（主色 #4A90D9 + 深浅变体、辅助色、危险色、警告色、中性色体系）、字体族栈（系统原生中文字体优先）、字号层级表（H1/H2/H3/Body/Caption 共 5 级）、基础间距尺度（4px 基准，6 级常用间距）。标注所有参数在 UI 设计阶段可微调。

### 16.12 多步骤表单的中间状态跨步骤持久化机制未明确（审查问题-一般，问题12）

**审查意见**：第 4.4 节风险预测采用分步向导，但 iframe 架构下 JavaScript 内存持久化与"数据不会因步骤切换而丢失"承诺存在潜在矛盾。

**修订**：
- 在第 4.4 节新增"表单数据跨步骤持久化"段落，推荐使用 sessionStorage 存储表单数据的跨步骤持久化方案（每步完成后序列化写入、每步进入时回填、提交成功或重填时清除、iframe 刷新后恢复）。
- 补充说明此机制依赖所有 iframe 页面同源部署的前提条件。

### 16.13 AI 助手对话中健康建议生成的意图识别与触发机制不明确（审查问题-轻微，问题13）

**审查意见**：第 4.8 节描述 AI 助手"可以"生成健康建议，但未说明"何时"触发。

**修订**：
- 在第 4.8 节新增"健康建议的触发机制"段落，明确健康建议由 Dify Agent 根据对话上下文自主决策触发（用户表达健康管理相关意图时），Agent 在回复中告知用户建议已生成。用户不需要前端显式按钮触发，触发判断逻辑在 Agent 系统提示词中定义。

### 16.14 前端模块的文件组织和构建方式未提及（审查问题-轻微，问题14）

**审查意见**：文档未提及是否使用构建工具、第三方库引入方式、源代码推荐目录结构。

**修订**：
- 在第 8.1 节"在范围内"列表中新增两条：（1）前端构建方式说明——采用原生 HTML/CSS/JavaScript 开发，不依赖构建工具，第三方库通过 CDN 或本地 lib 目录引入，并说明了选择的推断依据；（2）前端源代码推荐目录结构——按 pages/css/js/lib/images/uploads 分层组织。

### 本轮的跨节结构性变更

本轮修订涉及以下跨节的结构性调整：

- **第 1 节新增 1.2 小节**："前端路由结构"，覆盖路由方案选型、URL 路径映射表、路由守卫逻辑、iframe 子页面 URL 规范（问题 7）。
- **第 1.1 节末尾新增段落**："postMessage 消息协议规范"，定义 AUTH_SYNC/NAVIGATE/DATA_TRANSFER 三种消息类型的标准格式和 origin 校验方式（问题 5）。
- **第 4.4 节末尾新增段落**："表单数据跨步骤持久化"，推荐 sessionStorage 方案并说明 iframe 刷新恢复策略（问题 12）。
- **第 4.8 节新增段落**："健康建议的触发机制"，明确 Agent 自主决策触发而非前端显式按钮（问题 13）。
- **第 4.10 节新增段落**："Token 过期处理"，覆盖 HTTP 拦截器、SSE 对话中、多步骤表单中途、iframe 间同步四种过期场景（问题 8）。
- **第 5 节 AI 内容生成持久化路径段落扩展**：新增 life_advice 表的写入路径说明，纳入 AI 内容生成持久化路径覆盖范围（问题 2）；新增"Dify 平台能力验证任务"段落，含备选方案（问题 3）。
- **第 6 节导言部分新增段落**："请求参数映射说明"，定义 Express 代理层 message → query 等关键参数名映射关系（问题 9）。
- **第 6.4 节新增段落**："SSE 流内错误事件处理"，定义前端按 event 字段分类处理流内逻辑错误的策略（问题 6）。
- **第 6.9 节新增段落**："life_advice 表的写入路径说明"（问题 2）和 SSE 流内错误处理策略引用（问题 6）。
- **第 6.10 节重构**：新增 `POST /api/admin/chat` 端点（含请求体参数表，问题 1）；为 `POST /api/admin/execute` 新增 Dify Agent 回调场景和浏览器直连场景两组请求体参数表（问题 4）；更新 `/api/admin/execute` 端点说明标注浏览器直连场景已由 `/api/admin/chat` 替代。
- **第 7.1 节新增两个子节**："设计系统基础参数"（品牌主色调、字体族栈、字号层级表、基础间距尺度，问题 11）和"交互状态规范"（加载中/空数据/错误三类中间状态统一标准，问题 10）。
- **第 8.1 节新增两条**：前端构建方式说明（原生开发 + CDN 引入）和前端源代码推荐目录结构（问题 14）。
