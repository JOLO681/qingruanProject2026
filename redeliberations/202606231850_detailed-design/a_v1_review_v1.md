# 详细设计方案审查报告（v1）

## 审查结果

**REJECTED**

## 审查概要

本审查对照需求文档（`requirement.md`）和需求澄清文档（`1_requirements_analysis_v1.md`）对详细设计文档（`a_v1_design_v1.md`）的7大章节进行逐维验证。设计文档整体质量较高，覆盖了所有7大章节的全部要求，数据库DDL和API设计与SRS高度一致。但存在**2个一般级问题**（管理员首次登录强制修改密码机制缺失、Dify平台能力验证任务与备选方案缺失），需修改后方可通过。

## 逐维度审查

### 1. 设计章节完整性（对照requirement.md的7大章节要求）

**[通过]** 设计文档完整覆盖了requirement.md定义的7大章节：

- **系统架构详细设计**（第1节）：包含系统整体架构图、iframe SPA主框架架构图、技术选型详情表、模块划分与依赖关系、跨模块通信机制（postMessage消息类型枚举、origin校验实现、数据流图）、前端路由详细设计（hash路由映射表、路由守卫伪代码）、三条数据操作路径架构流程图。所有子项均已覆盖。
- **数据库详细设计**（第2节）：包含完整ER图（mermaid）、10张表的完整DDL、索引策略（含创建SQL）、初始数据INSERT脚本（3位医生、4类糖尿病类型、管理员账号、3篇示例文章）、完整数据字典。所有子项均已覆盖。
- **API接口详细设计**（第3节）：包含完整14组端点清单、每个端点的请求/响应JSON Schema、SSE流事件格式定义、统一错误响应格式及11个错误码枚举、分页响应统一格式、Express代理层参数映射表、postMessage消息协议完整定义。所有子项均已覆盖。
- **前端模块详细设计**（第4节）：包含各HTML页面的组件树（DOM结构伪代码）、状态管理方案表（localStorage/sessionStorage/内存变量使用边界）、各页面JS逻辑流程图（mermaid）、公共JS模块设计（api.js/auth.js/message.js/ui.js）、CSS设计系统（完整CSS变量+组件样式规范表）、交互状态组件设计（骨架屏/AI加载/空数据引导/错误重试/Token过期提示/流内警告）。所有子项均已覆盖。
- **Dify工作流/Agent配置设计**（第5节）：包含7个Dify应用的设计规格（系统提示词完整文本、输入变量定义表、输出结构定义、知识库配置、工具定义含回调URL模板）、工作流节点编排逻辑（mermaid flowchart）、Agent Function Calling模式选择及理由。所有子项均已覆盖。
- **部署详细设计**（第6节）：包含Nginx完整配置文件（服务器2/3反向代理+负载均衡、服务器1静态文件服务）、Express启动脚本和环境配置（.env.example、package.json）、SQLite初始化脚本、静态资源目录结构和Nginx location映射表、Keepalived主备方案。所有子项均已覆盖。
- **安全详细设计**（第7节）：包含JWT鉴权完整流程图、bcrypt密码哈希参数（盐轮数10）、/api/admin/execute双认证模式完整实现伪代码、iframe同源策略约束清单、XSS防御策略表、SQL注入防护策略表、CSRF防护策略表。所有子项均已覆盖。

**[轻微]** 第4.1.6节中profile.html、risk.html、punch.html、health-advice.html、login.html、admin.html的组件树标注为"(关键元素从略，以下列出核心差异)"。risk.html的三步向导进度指示器DOM结构、punch.html的日期筛选器DOM结构等关键交互UI元素未给出完整的DOM层级，实现者需自行推断部分DOM结构。考虑到其他页面的DOM结构已经足够详细，此问题不阻塞通过。

### 2. 设计决策与SRS约束一致性

**[通过]** 对照SRS（`1_requirements_analysis_v1.md`）已确定的约束，设计文档在各技术选型维度上保持一致：

- **前端技术栈**：HTML+CSS+JS（原生）、Tailwind CSS CDN（本地`/static/lib/`）、Swiper 11.x、SweetAlert2 11.x、Font Awesome 6.x、marked.js 12.x —— 与SRS第8.1节一致。设计进一步明确了CDN/本地引入方式（本地存放于`/static/lib/`），符合SRS要求。
- **前端架构**：SPA + iframe子页面、移动端优先375px基准、hash路由、目录结构（`/src/pages/`、`/src/css/`、`/src/js/`、`/static/lib/`、`/static/images/`、`/static/uploads/`）—— 与SRS第1.2节和8.1节完全一致。
- **后端技术栈**：Node.js + Express端口3000、SQLite单文件、JWT 24h过期、bcrypt密码哈希（盐轮数10）、SSE fetch+ReadableStream（不使用EventSource）—— 与SRS第4.10节和6.4节一致。
- **AI层**：Dify平台（工作流+Agent+聊天助手）、7个Dify应用名称（diabetes-risk-prediction等）、DeepSeek模型通过Dify间接调用—— 与SRS第5节和6.11节Dify工作流清单一致。
- **部署**：3台Linux服务器（8核16G）、服务器1数据服务器（SQLite+Express+Nginx静态文件）、服务器2/3负载均衡（Nginx反向代理+Keepalived主备）—— 与SRS第7.4节一致。
- **postMessage消息类型**：AUTH_SYNC、NAVIGATE、DATA_TRANSFER三种核心消息类型—— 与SRS第1.1节消息协议规范完全一致。设计进一步合理扩展了TOKEN_EXPIRED、HISTORY_BACK、LOADING、TAB_SWITCH四种辅助消息类型。
- **路由结构**：hash路由，12条路径映射—— 与SRS第1.2节URL路径映射表一致。
- **访问控制**：公开/需登录/需admin三级权限—— 与SRS第4.10节访问控制矩阵一致。
- **医学免责声明**：首次AI功能确认弹窗（localStorage持久化）、AI内容底部固定免责提示、医师对话界面免责标识条—— 与SRS第4.11节完全一致。
- **7个Dify应用的命名和功能归属**：与SRS第6.11节Dify工作流清单汇总表完全一致。

### 3. 数据库DDL完整性与SRS第5节一致性

**[通过]** 对照SRS第5节定义的10张数据表，设计文档的DDL完整覆盖了所有表，字段定义与SRS一致，并合理补充了约束细节：

- **users表**：id、username、password、avatar、role、created_at —— 设计新增updated_at字段（合理扩展），role字段含CHECK约束、默认值'user'，与SRS一致。
- **doctor_information表**：id、name、department、title、description、avatar、chat_token、created_at —— 完全一致，chat_token字段不暴露给前端（API响应中排除），与SRS安全要求一致。
- **articles表**：id、title、cover、author、content、category、views、created_at —— 完全一致，content为TEXT存储Markdown格式，author默认'AI健康助手'。
- **diabetes_types表**：id、name、image、pathogenesis、manifestation、treatment —— 完全一致，name含UNIQUE约束。
- **article_collections表**：id、user_id、article_id、created_at —— 完全一致，(user_id, article_id)联合UNIQUE约束防止重复收藏，外键ON DELETE CASCADE。
- **user_risk_info表**：id、user_id、age、gender、height、weight、family_history、waist、systolic_bp、pregnancy、raw_input、diabetes_type、result、created_at —— 完全一致，设计合理增加了CHECK约束（gender、family_history）和raw_input字段（存储原始输入JSON）。
- **life_plans表**：id、user_id、plan_type、order_num、time_desc、title、content、created_at、updated_at —— 完全一致，plan_type含CHECK约束，order_num默认0，与SRS时段映射约定一致。
- **life_advice表**：id、user_id、title、tags、content、created_at —— 完全一致，tags默认'[]'（JSON数组）。
- **punch_in表**：id、user_id、plan_id、punch_time、punch_type、completion_status、remarks —— 完全一致，plan_id外键ON DELETE SET NULL（方案删除后打卡记录保留），punch_type和completion_status含CHECK约束。
- **admin_logs表**：id、admin_id、operation_type、operation_time、operation_content、operation_result —— 完全一致。

索引策略覆盖了所有高频查询场景（用户名唯一索引、外键索引、复合索引），创建SQL完整。

初始数据INSERT脚本满足SRS要求：管理员账号（1条，含bcrypt哈希占位符和生成命令注释）、医生（3位不同科室，chat_token含占位符注释）、糖尿病类型（4类，含完整发病机制/表现/治疗文本）、示例文章（3篇，含完整Markdown正文）。

**[轻微]** life_plans表的plan_type CHECK约束包含'其他'枚举值，但SRS第4.5节和功能需求中未定义'其他'类型的用途。该枚举值目前无对应功能需求支撑，可能导致实现者困惑。

### 4. API设计完整性与SRS第6节一致性

**[通过]** 对照SRS第6节定义的全部API端点，设计文档完整覆盖了所有端点，参数定义和响应格式与SRS一致，并提供了SRS未包含的完整JSON Schema：

- **认证端点**（6.1节）：POST /api/auth/register、POST /api/auth/login、POST /api/auth/logout —— 端点、方法、认证要求、参数完全一致。设计增加了完整的请求/响应JSON Schema（含错误响应示例）。
- **用户端点**（6.2节）：GET/PUT /api/user/profile、PUT /api/user/password —— 一致。设计新增了PUT /api/user/profile请求体Schema和头像上传协作流程说明。
- **风险预测端点**（6.3节）：POST /api/risk/predict、GET /api/risk/history —— 端点、方法、参数完全一致。设计增加了完整的请求/响应Schema（含10个字段的详细结构和risk_score/risk_level等响应字段）。
- **医师咨询端点**（6.4节）：GET /api/doctors、GET /api/doctors/:id、POST /api/chat/doctor/:id（SSE）、GET /api/chat/doctor/:id/conversations —— 端点、方法、认证、参数完全一致。设计增加了SSE流事件格式定义、chat_token不暴露的说明。
- **生活方案端点**（6.5节）：POST /api/plan/generate、PUT /api/plan/adjust、GET /api/plan/current —— 完全一致。设计增加了health_info/preferences的详细子字段Schema和方案为空时的响应体。
- **打卡端点**（6.6节）：POST /api/punch、GET /api/punch/list、GET /api/punch/analysis —— 完全一致。设计增加了分页+筛选查询参数和punch/analysis的完整响应体Schema（含依从性评语和改进建议字段）。
- **健康资讯端点**（6.7节）：GET /api/articles、GET /api/articles/:id、POST /api/articles/generate、POST/DELETE /api/articles/:id/collect、GET /api/articles/collections —— 完全一致。设计增加了文章生成两阶段流程（分类推荐→文章生成）的完整Schema。
- **糖尿病类型端点**（6.8节）：GET /api/diabetes-types、GET /api/diabetes-types/:id —— 完全一致。
- **AI助手端点**（6.9节）：POST /api/assistant/chat（SSE）、GET /api/assistant/advice、GET /api/assistant/conversations —— 完全一致。
- **管理端点**（6.10节）：POST /api/admin/chat（SSE）、POST /api/admin/execute、GET /api/admin/logs —— 完全一致。设计增加了双认证模式的完整实现伪代码（7.3节）和两组请求体参数表（Dify回调场景+浏览器直连场景）。
- **Dify代理端点**（6.11节）：POST /api/dify/workflow/:workflow_id、POST /api/dify/agent/:agent_id —— 完全一致。
- **文件上传端点**（6.12节）：POST /api/upload/avatar —— 完全一致，增加了multipart/form-data格式说明和文件类型/大小校验规则。

**[通过]** SSE流事件格式定义了message、message_end、error、workflow_started、workflow_finished、agent_message、agent_thought共7种事件类型，覆盖了Dify原始事件格式。

**[通过]** 统一错误响应格式定义了11个错误码（400-BAD_REQUEST、401-AUTH_REQUIRED、401-AUTH_INVALID、403-FORBIDDEN、404-NOT_FOUND、409-CONFLICT、413-FILE_TOO_LARGE、415-UNSUPPORTED_FILE_TYPE、422-VALIDATION_ERROR、429-RATE_LIMITED、500-INTERNAL_ERROR、502-DIFY_ERROR、504-AI_TIMEOUT），覆盖了SRS要求的全部错误场景。

**[通过]** Express代理层参数映射表完整列出了message→query、业务字段→inputs.{field_name}等关键映射，与SRS第6节导言的参数映射说明一致。

**[通过]** postMessage消息协议定义了AUTH_SYNC、NAVIGATE、DATA_TRANSFER的完整JSON payload结构，与SRS第1.1节消息协议规范一致。

### 5. 前端设计与U+平台参考模式一致性

**[通过]** 设计文档的前端设计遵循了U+平台参考代码的技术模式：

- **目录组织**：`/src/pages/`（HTML文件）、`/src/css/`（样式）、`/src/js/`（公共JS）、`/src/js/pages/`（页面JS）、`/static/lib/`（第三方库）、`/static/images/`（预置图片）、`/static/uploads/`（用户上传）—— 与SRS第8.1节和U+平台目录组织方式一致。
- **Tailwind CSS类名风格**：组件样式规范表定义了统一的Tailwind类名组合（`bg-white rounded-lg shadow-sm p-4`等），与U+平台的原子化CSS风格一致。
- **第三方库引入**：Tailwind CSS、Swiper、SweetAlert2、Font Awesome、marked.js均通过本地`/static/lib/`引入，符合SRS原生开发不依赖构建工具的约束。
- **移动端优先**：CSS变量中定义`--max-content-width: 375px`，以375px为基准宽度的移动端优先设计。
- **SPA + iframe架构**：主框架index.html + iframe子页面的架构模式与SRS第1.1节描述一致。
- **DOM结构设计**：每个HTML页面的组件树使用缩进伪代码形式描述（类似DOM树），标注了关键的CSS class和交互元素，可直接指导HTML编写。

**[轻微]** 设计文档4.5.2节组件样式规范表中引用了`rounded-button`（如`rounded-button`），但CSS变量定义（4.5.1节）中仅定义了`--radius-sm/md/lg/full`四种圆角变量，未定义`rounded-button`变量。此处的`rounded-button`应为Tailwind工具类或需补充定义。

### 6. 逻辑矛盾、遗漏或与SRS不一致之处

**[严重]** 无。

**[一般]**

**问题1：管理员首次登录强制修改密码机制缺失**

- **问题**：SRS第5节"初始数据要求"明确要求"管理员首次登录后系统应强制跳转至密码修改页面，要求更换默认密码后方可继续使用管理功能"。设计文档仅在2.4节种子SQL中插入了管理员账号（含bcrypt占位符），在7.2节描述了bcrypt密码哈希机制，但未在任何章节涉及以下必要设计元素：
  - 管理员首次登录状态的检测机制（如users表是否需要`password_changed`标记字段，或通过比较密码哈希判断是否为默认密码）
  - 前端路由守卫中对管理员首次登录的拦截和强制跳转逻辑（1.6.2节路由守卫伪代码仅检查Token有效性和role，未检查first_login状态）
  - 强制密码修改页面的UI设计和交互流程
  - 后端接口对首次登录状态的处理（如登录接口返回`must_change_password: true`标志）
- **原因**：缺少此机制意味着管理员使用预置默认密码（如`admin123`）登录后可直接使用全部管理功能，违反SRS的安全要求，存在安全风险。
- **建议方向**：
  - 方案A（数据库标记）：在users表增加`password_changed`字段（BOOLEAN默认0），管理员首次登录时接口返回`must_change_password: true`标志，前端路由守卫检测后强制跳转至密码修改页，修改成功后更新`password_changed=1`。
  - 方案B（Token载荷标记）：在JWT payload中增加`pwd_changed`字段，首次登录时不设置此字段（或设置为false），路由守卫检查此字段决定是否拦截。优点是无需修改数据库结构，缺点是无法防止Token伪造。
  - 推荐方案A，因其不依赖客户端行为，安全性更高。

**问题2：Dify平台能力验证任务与备选方案缺失**

- **问题**：SRS第5节定义了"Dify平台能力验证任务"——需在开发环境搭建阶段实测Dify平台是否支持在Text2SQL工具回调请求体模板中引用`{{user}}`变量。SRS同时提供了备选方案（Express服务端维护session_id→user_id映射表）。设计文档5.2.5节和5.2.6节的Text2SQL工具定义中直接使用了`{{user}}`变量（"user_id": "{{user}}"），但：
  - 未提及此能力需在开发阶段前置验证
  - 未提供备选方案的实现设计（session_id映射表的生命周期、存储结构、清理策略）
  - 如果Dify平台不支持`{{user}}`变量透传，当前设计将无法工作，需返工
- **原因**：此假设若在实现阶段被证伪，将导致Text2SQL工具回调无法获取正确的user_id，进而导致行级权限约束完全失效（严重安全风险）或需要重构认证桥接机制（返工成本高）。
- **建议方向**：
  - 在设计文档中增加"Dify平台能力验证任务"小节（可置于5.2.5节或5.4节之后），明确验证步骤、验证端点和验证标准
  - 补充备选方案的详细设计：session_id映射表的数据结构（Map<sessionId, {userId, createdAt}>）、session_id的生成策略（uuid/crypto随机）、在difyService.js代理请求中的注入点、映射表条目的过期清理策略（登出时清除+定时扫描）、/api/admin/execute端点在备选方案下的参数结构变化（用session_id替代user_id）

**[轻微]**

**问题3：life_plans表plan_type的'其他'枚举值无功能需求支撑**

- **问题**：设计文档2.2节life_plans DDL中plan_type CHECK约束包含'其他'值（`CHECK(plan_type IN ('饮食', '运动', '其他'))`），但SRS第4.5节只描述了饮食和运动两种方案类型，'其他'类型未在任何功能需求中定义。API响应Schema中也未出现'其他'类型的方案。
- **原因**：可能是设计预留的扩展点，但在无对应需求的情况下，此枚举值会导致实现者不确定是否需要在前端为'其他'类型设计UI展示逻辑。
- **建议方向**：若'其他'确为预留扩展，在数据字典的plan_type字段说明中标注"当前版本仅使用'饮食'和'运动'，'其他'为预留扩展值"。若不需要，从CHECK约束中移除。

**问题4：Nginx CORS配置与同源部署假设的轻微不一致**

- **问题**：设计文档6.1.1节服务器2/3 Nginx配置中为`/api/`路径块配置了CORS头（`Access-Control-Allow-Origin`、`Access-Control-Allow-Methods`、`Access-Control-Allow-Headers`），并使用`$http_origin`作为`Access-Control-Allow-Origin`的值。但SRS第7.4节和设计文档自身多处明确API与前端同域部署。在同源部署下CORS配置属冗余（浏览器不会触发跨域检查）。此外，`$http_origin`回显请求Origin头的做法存在安全风险——若未对Origin值进行白名单校验，任何域名的跨域请求都会收到匹配的CORS头。
- **原因**：CORS配置可能是为开发环境（前后端分离调试）预留的便利性措施，但在生产环境同源部署下应为安全加固。
- **建议方向**：在CORS配置处增加注释说明"生产环境同源部署时可移除此CORS配置块；若需保留用于开发调试，应将`$http_origin`替换为具体的允许域名白名单"。

**问题5：CSS类名`rounded-button`未在CSS变量中定义**

- **问题**：设计文档4.5.2节组件样式规范表中多处引用`rounded-button`（如主按钮、次按钮、危险按钮的Tailwind类名组合），但4.5.1节CSS变量定义中仅有`--radius-sm/md/lg/full`四种圆角变量，未定义`--radius-button`变量，也未说明`rounded-button`是Tailwind的何种工具类。
- **原因**：可能是排版遗漏或`rounded-button`应为Tailwind的`rounded-lg`（对应`--radius-lg: 12px`）的别名，但未在文档中说明对应关系。
- **建议方向**：在CSS变量定义中增加`--radius-button: 12px;`（或指定具体值），或在组件样式规范中将`rounded-button`替换为具体值如`rounded-lg`。

### 7. 详细程度是否足以直接指导编码实现

**[通过]** 设计文档在以下方面达到了可直接指导编码实现的详细程度：

- **数据库层**：提供了可直接执行的完整DDL SQL语句（含所有字段、约束、默认值、外键）、索引创建SQL、初始数据INSERT语句（预置医生/文章/类型/管理员的具体内容文本）。实现者可直接将init.sql和seed.sql文件复制到项目中执行。
- **API层**：提供了每个端点的完整请求/响应JSON Schema（含字段名、类型、约束、示例值）、SSE事件格式逐字段定义、错误码完整枚举、分页响应格式。Express开发者可直接据此编写路由处理逻辑和参数校验。
- **前端组件层**：提供了大部分页面的完整DOM结构（含CSS class名）、JS逻辑流程图、公共模块函数签名和职责描述。HTML/CSS开发者可据此编写页面结构和样式。
- **Dify配置层**：提供了每个Dify应用的完整系统提示词文本、输入/输出变量定义、工作流节点编排逻辑图。Dify平台操作者可据此创建和配置应用。
- **部署层**：提供了完整的Nginx配置文件（可直接部署）、.env.example模板、package.json、数据库初始化脚本。运维人员可据此完成环境搭建。
- **安全层**：提供了/admin/execute双认证模式的完整实现伪代码、JWT鉴权流程、密码哈希参数。后端开发者可据此实现安全中间件。

**[轻微]** 第4.1.6节的6个页面DOM结构描述较为简略（仅列出核心差异），risk.html的三步向导进度指示器、punch.html的日期筛选器组件等关键交互元素缺少完整的DOM层级定义。实现者需参考其他页面的DOM结构模式自行推断，可能导致不同开发者实现的UI不一致。

## 修改要求

### 一般问题

**问题1：管理员首次登录强制修改密码机制缺失**

- **原因**：SRS第5节明确要求此安全机制，缺失将导致管理员使用默认密码即可操作全部管理功能，违反安全约束。
- **建议方向**：在users表增加`password_changed`字段（BOOLEAN默认0）；在POST /api/auth/login的响应体中增加`must_change_password: true`标志（当role=admin且password_changed=0时）；在1.6.2节路由守卫伪代码中增加首次登录拦截逻辑；在7.1或7.2节补充强制密码修改的接口调用流程。

**问题2：Dify平台能力验证任务与备选方案缺失**

- **原因**：SRS第5节明确定义了此前置验证任务和备选方案，设计文档直接假设`{{user}}`变量可用而未提供验证方案，若假设不成立将导致行级权限约束失效或需返工。
- **建议方向**：在5.2.5节或新增5.5节中增加"Dify平台能力验证"段落，定义验证步骤；补充备选方案的详细设计（session_id映射表结构、生命周期管理、清理策略、difyService.js中的注入点、/api/admin/execute端点的参数适配）。

### 轻微问题

**问题3**：life_plans表plan_type的'其他'枚举值——在数据字典中标注为预留扩展值，或从CHECK约束中移除。

**问题4**：Nginx CORS配置与同源部署不一致——在配置处增加注释说明生产环境可移除或使用白名单。

**问题5**：CSS类名`rounded-button`未定义——在CSS变量中补充定义或替换为已有变量值。
