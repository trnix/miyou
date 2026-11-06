# 米柚开发经验与工程规则

> 本文件是项目的持久记忆：所有规则都源自真实踩坑与实测验证，不包含推测。
> 写新代码前先读「ArkTS 踩坑清单」，接接口前先读「已验证接口表」，做交互前先看「动画规范」。

## 架构基线

- 工具链：hvigorw 命令行 / DevEco Studio（API 12 = HarmonyOS NEXT 5.0.0），纯 ArkTS + ArkUI
- 入口 EntryAbility hydrate 三件套：Session（登录 Cookie）、DeviceIdentity（设备指纹）、GlassTheme（沉浸光感档位）
- 网络层唯一出口 `net/MysHttp.ets`：request(GET) / postJson(POST)，返回 `{ httpCode, body, headerText }`；headerText 可能含凭据，界面不得直接展示
- 端点与版本号集中在 `net/Endpoints.ets`；各 Api 类自管请求头，登录后经 `Session.cookie()` 附带 Cookie
- 路由：`router.pushUrl` + JSON params；**新页面必须在 `main_pages.json` 注册**
- Tab 框架（AppShell）：系统 `Tabs` + 3 个 `TabContent`，`.barHeight(0)` 隐藏系统页签条，自定义悬浮药丸底栏保留；TabContent 天然懒挂载 + 常驻保活；切换动画只由 `TabsController.changeIndex` 驱动；`index` 参数**不绑定 @State**——它退化为纯点击高亮状态，点击时立刻写入（高光瞬移），页面滑动由控制器独立播放；`onChange` 同步横滑结果
- 频道栏样式唯一基准（首页/社区一致）：文字 + 底部 18×3 指示条，选中用频道专属色（GameInfo.color）、fontSize 17 Bold，未选 15 Normal #667085；项 padding 左右 10 上 8、flexShrink(0)，栏高 46，横滑 Scroll + 右侧「频道」胶囊（32×64）。文案取 GameCatalog.short，崩坏学园2 显示全称
- gid→游戏 映射以 `docs/gids-mapping.md` 为准（探测器实测 1..14）；net/GameCatalog.ets 与其一一对应，新增频道先复核映射
- 图片体验：正文/评论图统一用 `view/AdaptiveImage.ets`（16:9 预估占位 → onComplete 识别极端比例智能处理：超细 banner 徽标化、横幅真实比例全显不横裁、表情包小图限高全显、常规/长图按真实比例；每张缩略图用 onAreaChange 常驻记录全局 rect + 圆角 + 图片真实宽高伴点击上报）；头像与信息流图片定高 + `#F2F4F7` 占位底色
- 全局滚动条隐藏：Scroll/List 统一 `.scrollBar(BarState.Off)`
- 版本号纪律：versionName 只写 x.y.z 三段（不加 -b 后缀）；UI 展示版本经 `bundleManager.getBundleInfoForSelf` 动态读取（MineTab），改版本只需动 `AppScope/app.json5`
- **文档同代**：版本号、Endpoints.USER_AGENT、README、本文件功能矩阵必须与代码同代。README 曾停留在 0.6.0、UA 曾停留在 0.5.0 而代码已到 0.7.0——功能定稿/规则更新时同步更新说明文档，纳入每次交付清单

## ArkTS 踩坑清单（九条铁律）

1. 禁 any/unknown（arkts-no-any-unknown）。JSON 解析一律 `(raw as Record<string, Object>)['key']` 递归取值，配合 asStr/asNum/asBool 防御性提取，单条失败不丢整页
2. 索引访问类型受限：断言后取键必须写成 `(x as Record<string, Object>)['key']`，不能链式简写
3. @Builder 首层必须是 UI 组件语法：**不能有 const 赋值等中间语句**；需要中间值就写普通 helper 方法（如 floorStateOf/isFloorExpanded）在 Builder 内调用
4. build 内 if 条件必须引用响应式状态（@State/@StorageLink/@Prop）：普通字段写在条件里只会在首次合成时求值一次，之后永不重建（Tab 保活标记曾因此导致两个 Tab 空白）
5. 新建页面 .ets 必须登记 `entry/src/main/resources/base/profile/main_pages.json`，否则 router.pushUrl 静默失败（按钮可见、点击无反应，无任何报错）
6. 类型声明必须具名：禁内联对象字面量类型（arkts-no-obj-literals-as-types），回调参数结构也要先声明 interface
7. Tabs 的 `index` 属性绑定 @State 且直接写该状态会**瞬跳无动画**；要么只调 `TabsController.changeIndex` 接受高亮延迟，要么 **index 不绑定状态**、状态只控制高亮（本仓采用后者：点击高光即时 + 控制器播动画）
8. 诊断/日志 trace 必须追加式累积（' | ' 连接 + 长度截断保护），覆盖式只留最后一跳会丢中间证据——b146 验证期曾因此把「新代码已生效但仍失败」误判为「装错包」，白走一轮卸载重装
9. Image 默认 `draggable(true)`：长按时系统先起拖拽预览（膨胀鼓动层），浮于 CustomDialog 之上，松手才放行菜单——凡挂 LongPressGesture 的 Image 一律 `.draggable(false)`（AdaptiveImage 两分支、详情全屏预览图均已修）

## 动画规范（全开发流程固定）

> 本规范对所有新交互生效；新增动画类型必须先登记进本节再实现。

- 统一曲线：`Curve.EaseOut`，全站任何动画不改曲线
- 时长三级，按交互量级取用：
  - **90ms 显影**：预览飞行图解码完成后 90ms 淡入（其下同位是像素一致的真缩略图）
  - **180ms 布局微调 / 缩放还原**：组件自尺寸变化（AdaptiveImage 图片占位 → 真实比例过渡）；双击还原与关闭预视前把 scale 缩回 1 都是 180ms
  - **200~220ms 条件层显隐 / 一镜到底飞行**：预览、楼中楼展开面板、图片预览进出
  - **280ms 页面级切换**：仅系统 Tabs 滑动动画使用；页面路由转场用系统默认，不自定义时长
- 图片预览最终方案 = **单节点适变**（V5.1 定稿，已实测打开/关闭双向无闪烁）：
  - 预览只用一个 Image 节点：布局动画从缩略图 rect 飞到**图片真实比例的适应矩形**（终点与图片同宽高比 → Cover 在终点恰好等于 Contain，无过裁无回缩）；捏合缩放与双击还原都是对**同一节点**的 scale 变换；全程无任何节点交接窗口
  - flyingAlpha 只用于「打开解码门控」：预览挂载首帧上层图未解码时不画——底下的真缩略图依然在原位、像素恒定；解码完成才 90ms 显影（500ms 兜底防加载异常场景飞行不可见）
  - 关闭：scale>1 先 180ms 缩回 1 → 布局动画缩回缩略图 rect（不经过全屏）+ scrim 渐隐 → **飞行落位后原子卸载**，不做收尾淡出
  - 打开期闪烁实测根因：**Cover/Contain 双图交叉淡换的交接窗口**（双解码、透明度 0 节点延迟栅格化）；关闭期闪烁实测根因：**40ms 收尾淡出与飞行尾巴重叠**、提前透出底下真缩略图形成双影闪白
  - 结论铁律：**预览生命周期只有一个 Image 节点；除打开解码门控外，不再对飞行图做任何透明度动画**
  - 反面教材（已实测淘汰）：scale/translate 飞行帧差与终点偏移；整层透明度渐出幽灵；Cover 飞到全屏矩形导致横图过裁放大再缩回（V3）；双图交接（V4 打开期）；收尾重叠淡出（V5 关闭期）
- `onBackPress()` 拦截返回的路径必须与普通关闭共用一个函数，不能另起一条无动画的退出路径
- 手势交互（捏合缩放、拖移、横滑）瞬时跟随手指，**不设动画时长**；手势结束后的收尾才用 animateTo
- 图片预览双指缩放：预览页主图同一节点 scale；`previewBaseScale` 暂存倍数，下限 1.0 上限 6，双击 180ms 还原
- 系统已有的动画不重复造：router.pushUrl 的页面转场、Tabs 滑动、Toggle/Button 等默认可视反馈，一律保持原样
- 新交互默认带动画：写交互组件时先默认给上述级别之一的动画，不加是出于性能或其他原因的具体段落才允许例外

## 已验证接口表

### bbs 读接口（基础 web 头组即可，登录 Cookie 为可选增强；详情新版帖例外见下行）
- 信息流：`GET bbs-api-static.miyoushe.com/apihub/wapi/webHome?gids=&page=&page_size=`（gid→游戏 1/2/3/4/5/6/8/9/10 全部探测器实测，7 与 11+ 为空，映射详见 `docs/gids-mapping.md`）
- 帖子详情：`GET bbs-api.miyoushe.com/post/wapi/getPostFull?gids={真实game_id}&post_id=&read=1`（**新版格式帖需网页客户端身份**：x-rpc 四元组 2.102.0/4/device_id/device_fp + 逐请求 DS1/LK2 签名，缺了服务端静默降级为「请升级版本查看」；gids 取自 PostContext 真实记录不猜频道；正文五形态：NORMAL delta / PIC / UGC / HTML / JSON 字符串，PostModels 全归一为 text/image 块）
- 评论：`GET bbs-api.miyoushe.com/post/api/getPostReplies?post_id=&size=&is_hot=true&last_id=`（last_id 游标分页）
- 楼中楼：`GET bbs-api.miyoushe.com/post/wapi/getSubReplies?post_id=&floor_id=&gids=&size=&last_id=`（floor_id 取主评论 reply_id 数值部分，已实测）
- 搜索：`GET bbs-api.miyoushe.com/post/wapi/searchPosts?gids=&keyword=&last_id=&size=20&order_type={1最热|2最新}`
- 用户资料：`GET bbs-api.miyoushe.com/user/api/getUserFullInfo?uid=&gids=`（自己他人均可）

### 登录与设备
- 扫码登录：`passport-api.miyoushe.com/account/ma-cn-passport/web` 通道（app_id bll8iq97cem8，client_type=4），createQRLogin / queryQRLoginStatus；凭据从确认响应 tokens + Set-Cookie 双向归集
- 网页登录：Login.ets 内嵌 user.mihoyo.com webview，7 域 Cookie 归集 + v2 键判定；Session.compose 按键去重丢空值（空 v1 键会误导服务器判未登录）
- 设备指纹：`public-data-api.mihoyo.com/device-fp/api/getFp`，device_id/device_fp 成对稳定持久化

### 已知受限（客户端无解，勿再试）
- `post/wapi/userPost`：任何 uid 都返回 1001 权限不足（服务端风控），他人主页帖子区与 MineTab 跳自己主页均因此受限
- R4 游戏战绩（game_record 域）：未重测维持下架。DsSign.ets 已随网页身份修复回归（DS1/LK2 + DS2/x6 对照实现），但 game_record 完整 DS2 链路未验证

## 功能矩阵（当前真实状态）

| 功能 | 状态 |
|---|---|
| 首页推荐流 | ✅ 九游戏频道切换（gid 映射探测器实测）+ 下拉刷新 + 上拉分页 |
| 社区搜索 | ✅ 按游戏 + 最热/最新 + 游标分页；频道栏与首页同款（文字+指示条、频道专属色） |
| 帖子详情 | ✅ 标题/话题/结构化正文/图片点击全屏预览并双指缩放；新版格式帖已解锁（网页身份 + DS1，b147 真机验证） |
| 评论区 | ✅ 热评分页 + 楼中楼可点展开（每楼层独立状态，带动画） |
| 用户主页 | ✅ 资料卡 + 他人帖子列表（自己帖子受 1001 限制） |
| 我的 | ✅ 登录身份卡（头像/昵称/UID/简介/四项数据，@Watch 随登录态刷新）+ 沉浸光感开关 + 动态版本号 |
| 登录 | ✅ 官方网页登录 + 扫码登录，Cookie 清洗持久化 |
| Tab 框架 | ✅ 系统 Tabs 滑动动画 + 横滑手势 + 保活不重载 + 点击高光即时同步 |
| 图片体验 | ✅ AdaptiveImage 智能比例 + 预览 V5.1 单节点一镜到底（已实测双向无闪烁）+ 捏合缩放/双击还原 + 缩放关闭先还原 + 侧滑只关预览；长按菜单即时弹出无遮挡（draggable(false)） |
| 动画规范 | ✅ 全站统一 Curve.EaseOut；预览 = 单节点适变（除解码门控外飞行图零透明度动画）；楼中楼 transition + animateTo |
| 消息 | ❌ 入口已移除（官方接口未接入） |
| 版区频道页 | ❌ R7 取消（降级后与首页重叠，ForumHome.ets 已删） |
| 游戏战绩 | ❌ R4 放弃（DS 签名链路复杂度高，相关文件已删） |

## 当前进度

v0.7.0 收束：R6 楼中楼；性能三件套；系统 Tabs 动画与保活；AdaptiveImage 智能比例；预览动画五轮迭代定稿 V5.1 单节点适变（打开/关闭闪烁均已实测消除）；动画规范统一；MineTab 身份卡；README/UA/文档同代修正。

v0.8.0：新版格式帖解锁——F12 实捕对齐网页客户端身份（x-rpc 四元组 2.102.0/4/device_id/device_fp + 逐请求 DS1/LK2 签名，新增 net/DsSign.ets）；详情诊断升级为四变体头组对照；trace 改追加式（铁律 8）；getSemPosts 降级为精准 ID 命中的兜底安全网。社区频道栏样式与首页统一（文字+指示条、频道专属色、46 高）；崩坏学园2 频道显示全称（GameCatalog.short 一处改，三处生效）。gids→游戏 全映射探测器实测归档（docs/gids-mapping.md，修正「崩坏3 错位」旧误记：崩坏3=1、崩坏学园2=3）；修复帖子图片长按被系统拖拽预览盖住菜单（铁律 9：挂长按手势的 Image 一律 draggable(false)）。

原则重申：读接口、读源码、读真实文件后再动手；不写推测的 API 形态；功能降级与重叠宁可删除不留壳。
