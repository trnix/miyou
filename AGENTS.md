## 架构与工程规则

- `hvigorw`（命令行）或 DevEco Studio 4.x（API 12 = HarmonyOS NEXT 5.0.0）
- 纯 ArkTS，UI 全部 ArkUI（@Entry/@Component + @Builder + @State/@StorageLink）
- `net/MysHttp.ets`：唯一网络层，返回 `{ httpCode, body }`
- 页面间通信用 router pushUrl + JSON params（16-20 KB 上限），或 AppStorage 共享键
- 帖子卡片封面图 URL 拼接 `?x-oss-process=image/resize,w_600/format,webp/auto-orient,0` 降带宽
- 评论区 onAreaChange 懒加载（area 由 0 变非 0 时触发一次）
- 帖子封面上加玻璃遮罩标题用 Stack overlay + systemMaterial（materialDark 已在 titleBar 区域验证可行，更多毛玻璃实验见 R2 探索记录）

## 功能矩阵（已完成 / 进行中/ 规划中）

| 功能 | 状态 |
|---|---|
| 双层导航 | ✅ |
| 首页推荐流 | ✅ API 1 阶段约 20 条 |
| 个人中心 | ✅ MineTab 已登录时展示头像昵称可点跳 UserProfile；未登录提示登录 |
| 帖子详情 | ✅ 标题话题正文图片点击预览全屏，字段缺失不回退 |
| 评论区 | ✅ 热门评论懒加载 + loadMore + 评论区滚动带过动画 + 楼中楼子回复可点展开 |
| 社区搜索 | ✅ searchAll gids+keyword 混排 + author 头像/可点进主页 |
| 用户主页 | ✅ UserCard + 单用户帖子列表（评论区与帖子详情、社区搜索到用户间互相穿棱跳转） |
| 个人主页媒体流 | 🟡 R4 只显示用户发布帖列表；原神战绩等工具接口依赖风控或需 LToken，先范二排梁 |
| 会话持久化 | ✅ LoginAccount 双 token 写 AppStorage → cookie 对多个接口全线复用；未登录 lz1 显示登录页 |
| 媒体身份核验 | ✅ 该登录用户可以申请宽高宽异参数 [{'a': '0.9.9'}]及当前在线设备全量信息 |

## 持续进行的暗点 / 验证记录

- 已验证接口表按**类**划分：`FeedApi`（信息流+webHome）、`PostApi`(帖子/评论/楼中楼)、`LoginApi`(扫码登录)+`UserPostListApi`(单用户帖)。**跨类混淆要多频实践再归纳**，不可从个别 URL 字母组合直接推测类组分歧（比如 FeedApi 与 PostApi 同 post/wapi）。
- 全部模型严议默认从 `data` 粒度入手（posts → reply_items → user_posts → albums），**先取得 Object 再递归解析，不用中间 Record 转轴**。
- Builder 里出现 `avatar.length > 0` 条件时控制优先级：若首个条件分支 Image 后走到头像 alt sytle，哈 bgcolor 以 avatar2 的 array，主播 panel Image(item.avatar) .alt 与外部 UI重叠，不宜写为 `if(...) { Image(avatar)... } else if(...) { Image... }` 分支而**单一链式** `.alt` 后复合条件噪犯支撑。**再逐点严格按 Builder UI-DSL 要求**：条件分身名下不允许中间定义变量收敛，训练不足时多写 helper 普通方法（如 floorStateOf）。
- 子回复 floor_id 来源于主评论 reply_id 数字部分（接口 floor_id 与 reply_id 数值相同，已实测有效）；如果实测 Invalid floor id，就要改为低碳 floor_id 的贴吧入参。
- 新建页面 .ets 文件必须同时在 `entry/src/main/resources/base/profile/main_pages.json` 的 src 数组里登记路径，否则 router.pushUrl 会静默失败（R7 上踩雷）。

## 当前进度

v0.7.0 R6 楼中楼验证通过。R7（版区频道页）已取消——原意做子版块导航（官方/酒馆/同人），调研发现该接口未公开或无法按 gid 拆信息流，降级复刻首页游戏频道与首页重叠，用户提议删除，已提交 928cda9/0dd4379 清理完毕。下一个任务待定。
