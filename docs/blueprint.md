# 米柚原生重写 · 移植蓝图

> 版本 v1.6 ｜ 2026-11-02（v1.0/v1.1 见 2026-10-30，v1.2–v1.5 同月）
> 定位：重写版的需求基线。后续开发任务拆解、验收均以本文档为准；变更需修订本文档并升版本号。
> 依据：米游社 2.117.0 APK 逆向分析报告、「米柚开发」资料包、docs/handover.md、M0 真机实测（登录/Cookie/探活）、官方 App 四张页面截图（消息/关注/我的/频道）、官方文档镜像核验记录。

## v1.6 变更摘要

- **R3 消息中心实装**：聊天/通知双 tab + 三快捷入口（评论和@/新增关注/收到的赞，各带未读数）+ 分类通知列表（头像/昵称/摘要/时间/未读点，点击可跳关联帖子）+ 分页；底栏消息键 Badge 未读角标（AppStorage `msgUnreadTotal` 联动）。
- **消息端点为推测候选**：公开社区（UIGF 归档仓库、GitHub 全站、中文社区）均无米游社消息接口文档，第三方工具生态基本不做消息中心。候选端点 `apihub/sapi/getMessageCnt` 与 `apihub/sapi/getNotifyList?type=` 按 apihub 网关既有形态（搜索接口在案）推测，采用「网页头→x-rpc 全头」双通道自动重试，失败时页面出可复制诊断卡（HTTP 码/retcode/body 截断），真机验证一次即可校准。
- **聊天 tab 为协议性不做**：米游社私信由自研 IM 长连接承载（模块表 #20 早已定论），页面给降级说明，引导查看通知 tab。

## v1.5 变更摘要

- **评论浏览实装**：`getPostReplies` 接入，新增 `ReplyModels.ets`（防御性解析）；详情页底部评论区（头像/昵称/时间/正文/点赞数），热门评论 + last_id 手动分页去重；楼中楼仅显示「共 N 条回复」提示，展开归 R6；评论独立异步加载，失败降级不阻塞正文。R2 至此收尾。
- **图标链路修复**：删除 CI `Restore binary assets` 步骤（该步骤每次构建都从 0.4 归档分支覆盖新图标，为图标长期不显示的根因）；清理两处 `.alt($r('app.media.foreground'))` 悬空引用，统一改用 `app_icon`。

## v1.4 变更摘要

- **R2 帖子详情开工**：`getPostFull` 接入，新增 `PostModels.ets`（防御性正文归一：text/image/unknown 三态 + HTML 兜底）、`PostApi.ets`、`pages/PostDetail.ets`；首页卡片点击跳转详情；图片支持点击进入全屏预览（点按关闭）；评论区与视频播放保持占位，归 R6。
- **应用图标**：用户决定使用其提供的《原神》派蒙图片（自用、不开源、不分发）。版权归属米哈游，仅限个人设备侧载场景；任何对外分发前必须替换为合规原创图标。风险注记已写入 handover。

## v1.3 变更摘要

- **光感设置简化为开关**：设置页由「关闭/弱/中/强」四档按钮改为「沉浸光感」文字 + 胶囊开关（ToggleType.Switch）；实测弱/中档视觉差异不可辨，予以移除。开关语义：关=0（不透明遮罩）、开=3（THICK 强档）。
- 持久层兼容：AppStorage/preferences 仍存 0–3 数值；旧存的 1/2 在 hydrate 时归一为 3，新装默认开。

## v1.2 变更摘要

- **uiMaterial 正式解禁**：`@ohos.arkui.uiMaterial` 于 API 26（HarmonyOS 6.0/7）作为官方沉浸光感材质能力正式提供（元服务可用），0.4.0 时代的真机闪退是实验性 API 尝鲜阶段的问题，不构成永久禁令；启用前提是能力探测与属性顺序规则（见 3.2.7）。
- **崩坏3 频道正式下架**：实测 gids=3 返回崩坏学园2 内容，正确值无法考证，频道从信息架构与 R1 验收标准中移除；原「四频道」降为「三频道」。
- **档位表改写**：3.1 节从旧 BlurStyle.COMPONENT_* 方案（从未编译通过）改为实测可用方案（ImmersiveStyle 枚举 + materialColor 遮罩）。
- 补充布局实现要点：覆盖式沉浸结构、触摸透传、安全区动态监听（3.2 节）。

## 0. 总原则

1. 蓝图对标官方：信息架构、模块边界、页面流以官方 App（逆向报告第 3 节模块划分 + 官方截图）为参照；实现为纯 ArkTS/ArkUI 干净重写，不使用官方任何代码、bundle 与素材。
2. 只读先行：前期不实现任何远端写入（发帖/评论/回复/点赞/关注/收藏/签到/反馈）。网络层预留 DS1/DS2 签名与完整 Cookie 能力，写功能归入 R7 灰度，开启前单独风险评估与用户明示。
3. 防御性实现：接口字段缺失/变动不得导致崩溃；统一 snake_case→camelCase 映射层 + 缺省兜底。
4. 官方材质 API 启用规则：`uiMaterial.ImmersiveMaterial` 为 API 26 正式能力，允许使用；必须配 `hdsMaterial.getSystemMaterialTypes()` 能力探测，能力不支持时自动回退；必须遵守属性顺序规则（3.2.7）。
5. 资产约束：bundleName 固定 `com.miyou.app`（签名 Profile 绑定，不可改）；图标为米哈游版权素材、仅限自用不分发，对外分发前必须替换（见 v1.4）。

## 1. 信息架构（对标官方）

```
米柚
├── 首页（游戏频道 tabs：原神·星铁·绝区零；频道内含子版与发现流）
├── 社区（版区浏览：官方资讯 / 攻略 / 同人 / 酒馆等子版块）
├── 消息（只读：聊天 / 通知 双 tab + 评论和@ / 新增关注 / 收到的赞）
└── 我的（资料区 / 角色卡 / 战绩 / 实时便签 / 设置）
```

说明：官方底栏为 5 键（首页/关注/发布+/消息/我的）。米柚只读定位不设发布键，底栏维持 4 键悬浮玻璃胶囊（差异化保留）；页面内容区布局向官方对齐（见 3.3 节）。崩坏3 频道暂缺原因见 v1.2 变更摘要。

## 2. 功能模块总表

| # | 模块 | 官方参照（逆向+截图） | 米柚取舍 | 优先级 | 读/写 | 状态/数据基础 |
|---|---|---|---|---|---|---|
| 1 | 启动与主壳 | SplashActivity / HyperionMainActivity | ArkUI 四标签 + 光感玻璃顶/底栏 | P0 | 读 | ✅ M0 完成 |
| 2 | 登录 | PorteLoginActivity / PorteQRConfirmActivity | 网页登录（user.mihoyo.com）+ Cookie 捕获清洗；扫码登录 R4 补齐 stoken | P0 | 读* | ✅ 网页登录完成（v2 Cookie）；扫码待做 |
| 3 | 首页信息流 | RN bundle + 频道页（图4） | 游戏频道 tabs + 子版 + 发现卡片流；崩坏3 暂下架（gids=3 实测返回崩坏学园2 内容） | P0 | 读 | ✅ R1 完成；webHome/getNewsFeed |
| 4 | 帖子详情 | PostDetailActivity / UgcPostDetailActivity | 结构化富文本按块渲染，未知块降级 | P0 | 读 | ✅ R2 完成；getPostFull |
| 5 | 设置 | MysSettingsActivity | 沉浸光感开关 / 账号 / 缓存 / 关于 | P0 | 读 | ✅ 沉浸光感开关完成；其余随迭代 |
| 6 | 版区浏览 | TopicActivity / RelateTopicActivity | 游戏版区 + 子版块列表 | P1 | 读 | R6 |
| 7 | 评论浏览 | CommentDetailActivity / CommentReplyActivity | 热门评论 + 分页；楼中楼 R6 | P1 | 读 | ◐ 热评与分页完成（v1.5）；楼中楼归 R6；getPostReplies |
| 8 | 我的角色/战绩 | game_record 体系 + 我的页角色卡（图3） | 角色卡轮播 + 原神/星铁/绝区零战绩 | P1 | 读 | R5；**需 stoken**（实证：ltoken 调 record 域 -10001） |
| 9 | 实时便签+服务卡片 | 6×AppWidgetProvider | 便签页 + Form Kit 卡片（体力/开拓力） | P1 | 读 | R5；需 stoken；刷新 ≥30min |
| 10 | 图片浏览 | PictureViewerActivity / ImagesViewerActivityV2 | 图片网格 + 缩放预览 | P1 | 读 | ◐ R2 已带基础全屏预览；缩放/网格归 R6 |
| 11 | 消息中心 | MsgListActivity + 消息页（图1） | 聊天/通知双 tab + 三快捷入口 + 通知列表（只读） | P2 | 读 | ◐ v1.6 实装（候选端点待真机校准）；聊天为协议性不做 |
| 12 | 视频播放 | VideoDetailActivity（ijkplayer） | Video 组件播放 | P2 | 读 | R6 |
| 13 | 搜索 | GlobalSearchActivity | 帖子/用户/版区搜索 | P2 | 读 | R6 |
| 14 | 用户主页 | UserHomePageActivity / UserProfileActivity | 资料卡 + TA 的帖子 | P2 | 读 | R6 |
| 15 | 合集/专题 | CollectionDetailActivity 等 | 合集详情浏览 | P2 | 读 | R6 |
| 16 | 计算器/抽卡分析 | event 网关 | 养成计算器 + 抽卡分析（authkey） | P2 | 读 | R6 后评估 |
| 17 | 每日签到 | event/luna/sign（DS2 6X） | 写-灰度 | P3 | 写 | R7 独立评审 |
| 18 | 点赞/关注/收藏 | postUpvote 等 | 写-灰度 | P3 | 写 | R7 独立评审 |
| 19 | 发帖/创作中心 | PublishActivity / DraftBoxActivity | 不做（早期）；R7 后重评估 | — | 写 | 风控最重 |
| 20 | IM 单聊 | SingleChatActivity（自研 IM） | 不做：私有协议 | — | — | — |
| 21 | 支付/米游币 | CashierActivity / 米游币中心 | 不做 | — | — | — |
| 22 | 游戏中心 | GameCenterActivity | 不做 | — | — | — |
| 23 | 青少年/举报/申诉 | Teenage / HyperUserReport | 不做：官方合规职能 | — | — | — |
| 24 | 扫码 | ScanActivity（MLKit） | 不做（无互扫场景） | — | — | — |
| 25 | 自更新 | DownloadIntentService | 不做：Release 页手动更新 | — | — | — |
| 26 | 推送 | JPush + 厂商通道 | 不做远程推送；本地通知（便签提醒）随 R5 | P2 | 读 | Notification Kit |

## 3. 视觉与交互规范：沉浸光感玻璃

设计目标：顶栏与底栏呈现鸿蒙沉浸光感玻璃拟态，与系统状态栏/导航条视觉融合，用户可在设置中一键开关。

### 3.1 开关映射（设置页「沉浸光感」）

设置项形式：左侧「沉浸光感」标题，右侧胶囊型开关（ToggleType.Switch，选中色 `#1570EF`），切换即时生效。

| 状态 | 视觉效果 | 技术参数（v1.3 实测定型） |
|---|---|---|
| 关闭 | 纯色不透明 | ImmersiveMaterial(style=REGULAR, interactive=false, materialColor=不透明 #FFF7F8FA)；不透明 materialColor 遮住材质层滤镜，等同无玻璃效果 |
| 开启（默认） | 厚重光感 | ImmersiveStyle.THICK + interactive=true + lightEffect(White) + 0.5vp 半透明白边 |

### 3.2 实现要点（实测结论持续累积）

1. EntryAbility 调 `setWindowLayoutFullScreen(true)`；底部安全区须同时查 `TYPE_SYSTEM` 与 `TYPE_NAVIGATION_INDICATOR` 取最大值（手势设备小白条报后者，只查前者会得到 0），且需监听 `avoidAreaChange` 并在 onWindowStageDestroy 释放。
2. 沉浸结构为三层叠加：底层全屏底色 → 全屏内容层 → 顶部覆盖层（标题栏，不占据内容空间）。非首页页面用顶端 padding 避让标题栏；首页用 List 的 `contentStartOffset`/`contentEndOffset` 做首尾避让，卡片滚动时从栏背后经过。
3. 覆盖信息流的全屏透明容器（标题栏外层包层）必须调 `hitTestBehavior(HitTestMode.None)`，否则会拦下列表滚动手势。
4. 系统栏配色：statusBarColor/navigationBarColor 设透明，statusBarContentColor/navigationBarContentColor 设深色（适配浅色底）。
5. 开关状态：AppStorage + preferences 持久化（键 glassLevel，0=关 / 3=开；旧四档的 1/2 在 hydrate 时归一为 3），`@StorageLink` 联动即时生效。
6. 底栏为悬浮圆角胶囊（margin 16、padding 8、圆角 32、shadow、高光描边），避让小白条 12vp + 安全区。
7. **属性顺序规则（官方文档）**：`backgroundColor` 必须写在 `systemMaterial` 之前——同设时后设置的生效，背景色写在材质之后会整段覆盖材质模糊，磨砂将不可见。此规则作为 GlassTheme 的调用约定，禁止颠倒。

### 3.3 官方 UI 对齐规范（截图拆解）

原则：内容区布局、卡片结构、信息层级向官方靠齐；顶/底栏保留米柚玻璃差异化；不使用官方素材与图标（图标用系统符号或自绘近似）。

**底栏**：官方 5 键固定栏（首页/关注/中央发布键/消息/我的 + 角标）。米柚 4 键悬浮玻璃胶囊：首页/社区/消息/我的，消息键需支持未读角标（v1.6 已实装 Badge）。

**信息流卡片（关注/发现，图2/图4）**，自上而下：
1. 作者行：圆形头像 40vp + 昵称（15sp 中黑）+ 认证蓝标 + 右侧「时间 · 在XX发布了帖子」（12sp 灰）。
2. 「官」方标：浅蓝底蓝字小 pill（官方账号帖子）。
3. 标题：17sp 粗体，最多 2 行。
4. 摘要：14sp 灰，最多 2 行截断。
5. 媒体区：图片 2 列网格、圆角 8vp；多图末张叠「+N」角标；视频卡带时长角标（mm:ss）。
6. 话题 pill 行：浅蓝灰底、13sp，可多个。
7. 互动行：转发/评论/点赞三枚，图标 + 数字（13sp 灰），米柚只读不可点或点了提示「只读」。

**消息页（图1）**：顶部「聊天 / 通知」分段 tabs（通知带总数角标）+ 右上设置齿轮；通知 tab 内顶部三快捷入口（评论和@ / 新增关注 / 收到的赞，图标+文字均分）；通知项：头像+认证标、标题 16sp 粗、摘要 13sp 灰一行、右侧时间（7小时前/10-29）与未读蓝点或数量泡。

**我的页（图3）**：蓝色渐变头图（带品牌纹理）为底的资料区：头像框、昵称+编辑标、UID/性别/IP 属地、签名行、成就 pill 云（半透明蓝底多枚）、粉丝/关注/获赞统计行；其下角色卡横向轮播（游戏立绘底深色卡：区服+等级、活跃天数、成就达成数、深境螺旋、幻想剧诗）；再下四快捷入口（创作中心/米游铺/兑换中心/奇匠中心，米柚替换为战绩/便签/签到(灰)/设置）；内容 tabs：发布/评论/合集/收藏 + 右上搜索。

**频道页（图4）**：深蓝游戏主题头图区域：顶部游戏 tabs（原神/绝区零/大别野/…）+ 菜单与搜索图标；工具图标横行（旅行工具/签到福利/绮星盛会/同人征集/归忆星旅/养成计算，可横滑）；资讯 banner（「资讯」标 + 文案 + 全部>）；其下白色圆角 sheet（顶部圆角 16vp）叠层：子版 tabs（观测枢/发现/官方/酒馆/攻略/同人图/COS）+ 发现卡片流（卡片结构同上）。

**配色**：主蓝 `#00C3FF`（官方主题蓝近似，按钮/选中/未读点）；官标浅蓝底 `#E5F6FF`；页面底 `#F7F8FA`；卡片白；标题 `#101828`；摘要 `#667085`；频道页头图深蓝渐变。

## 4. 技术底座需求（含实证）

- 包名：`com.miyou.app`；目标 API 26（HarmonyOS 7）。
- 网络层：x-rpc 基线 `app_version=2.117.0`、`client_type=5`、`verify_key=bll8iq97cem8`、UA 含 `Hyperion`；裸请求（仅 UA+Cookie）对 bbs 读接口同样可用（实证），优先按接口要求选择。
- **Cookie（实证结论）**：2026 起通行证登录态主体为 v2 键（`ltoken_v2/ltuid_v2/account_id_v2/cookie_token_v2`），同名 v1 键为空值占位；多域拼接必须按键去重、丢弃空值（空 v1 在前会被服务器判未登录）；uid 取自 `ltuid_v2`/`account_id_v2`。Session.save 已实现清洗。
- **认证等级（实证结论）**：bbs 系读接口（getUserFullInfo 等）用 ltoken Cookie 即可（retcode 0）；`game_record`（api-takumi-record）用 ltoken 调返回 -10001，**必须 stoken**；stoken 需扫码登录或账密+login_ticket 换发 → R4。
- 设备身份：`device_id` 首启生成持久化；登录后 Web Cookie 自带 DEVICEFP，`x-rpc-device_fp` 可取之，getFp 在线获取暂缓。
- 签名：DS1/DS2 通用实现已就位（DsSign.ets），salt 配置化留空待填。
- 错误处理：retcode -100/-10001 统一跳登录；1034/限流指数退避；网络异常页面级兜底文案。
- 渲染：结构化内容按块映射组件；未知块/缺字段降级占位，不得崩溃；`post.content` 可能为 HTML（Quill 纯文本帖），须有 HTML 兜底解析。
- **消息接口（v1.6）**：无公开文档，候选端点 `apihub/sapi/getMessageCnt`、`apihub/sapi/getNotifyList?type=` 为推测，双通道（网页头→x-rpc 全头）自动重试 + 页面诊断卡兜底，真机校准后回填本条。

## 5. 开发顺序（R1–R7）

| 序 | 模块 | 内容 | 数据基础 | 验收标准 |
|---|---|---|---|---|
| R1 | 频道发现信息流 | 游戏频道 tabs（三频道：原神/绝区零/星穹铁道）+ 子版 tabs + 发现卡片流（图4结构），首屏与分页 | webHome / getNewsFeed（无需 stoken） | 三频道切换、卡片按 3.3 规范渲染、下拉刷新、弱网降级 |
| R2 | 帖子详情 | 标题/作者/正文块（文字/图片/视频占位）/互动计数/话题；图片网格与预览；评论浏览 | getPostFull + getPostReplies | 主流帖子完整渲染不崩、图片可放大、未知块有兜底、热门评论可翻页 |
| R3 | 消息中心（只读） | 聊天/通知双 tab、三快捷入口、通知列表（图1结构） | bbs wapi（ltoken 已验证可达）；消息端点候选制+诊断校准 | 通知列表加载与未读展示；接口不可达时给降级说明；底栏未读角标联动 |
| R4 | 扫码登录 + stoken 换发 | 米游社 App 扫码流程（生成二维码→轮询→确认→取 stoken）；账号槽扩展 | passport-api 扫码接口 | 扫码全流程真机通过，stoken 落库，record 域探活转 0 |
| R5 | 我的角色/战绩/便签/卡片 | 我的页资料区+角色卡轮播（图3结构）、原神/星铁/绝区零战绩与实时便签、Form Kit 服务卡片、本地提醒 | game_record（stoken） | 角色卡数据完整、卡片 ≥30min 刷新 |
| R6 | 只读补全 | 搜索、用户主页、合集、评论楼中楼、视频播放、版区浏览 | bbs wapi | 各模块验收用例通过 |
| R7 | 写功能灰度（远期） | 每日签到（DS2/6X）、点赞/关注 | DS2+stoken | 独立评审：风控评估 + gt4 兜底 + 小号灰度 + 用户明示开关 |

## 6. 风险与边界

- 接口时效：全部 API 为社区逆向，随时可能失效；渲染层兜底 + 版本/salt 配置化是生命线。
- **消息端点不确定性（v1.6 新增）**：消息接口无公开文档，候选端点可能 404 或结构不符；若真机诊断确认不可达，R3 验收以「降级说明清晰、其余 tab 不受影响」为准，通知列表转入长期观察项。
- 账号风控：device_fp/device_id 成对稳定；触发 gt4 滑块走 Web 组件兜底。
- stoken 依赖：战绩/便签/签到类全部依赖 R4 扫码；扫码流程本身也属逆向，存在被官方调整的风险，需留「网页战绩查看」降级路径。
- 合规：README 与关于页保留「非官方、仅查看授权数据」声明；不收集账密；Cookie 仅存本机；图标为米哈游版权素材、仅限自用不分发。
- 签名资产：7 个 Actions 变量为唯一签名链路来源，任何重构不得输出其明文。

—— 蓝图以上。开发中如与本文档冲突，先改文档再改代码。
