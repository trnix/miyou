# 新版格式帖解锁：网页客户端身份（x-rpc + DS）

状态：已修复并真机验证（b147，帖子 79139530 正常渲染正文与评论）。

## 症状
部分新发帖详情 getPostFull 返回 HTTP 200、retcode=-1、data=null、message=「请升级版本查看」。旧帖正常。

## 排查路径（每步均有变体诊断证伪/证实，勿再走回头路）
1. URL 参数组：read=1 / 无 read / read=2，wapi 与 api 双路径——全部同一拒绝。参数形态不是解锁条件。
2. gids 参数：F12 成功 URL 为 getPostFull?gids=8&post_id=…&read=1，补 gids（取自 PostContext 真实 game_id，不猜频道）后仍拒绝——gids 是必要非充分条件。
3. getSemPosts 兜底：设备诊断证明其为语义相关帖列表（候选均不含目标 ID），仅在精准 ID 命中时可包装，不是详情通道。
4. 决定性证据：浏览器 F12 完整 Request Headers。成功请求除 URL 外还带 x-rpc 四元组（app_version=2.102.0、client_type=4、device_id、device_fp）与 Ds 头（时间戳,6位随机串,md5，逐请求实时计算）。米柚当时这些头一个都没发。
5. 旁证：该 F12 请求 Remote Address 为本地代理 127.0.0.1:7890 仍成功——排除 TLS/IP 指纹，问题只在 HTTP 头与 Cookie 层。

## 结论（根因）
服务端对新版格式内容按「网页客户端身份」静默降级：缺 x-rpc 头族 + DS 签名即回「请升级版本查看」，与参数、帖型、Cookie 均无关。公开社区资料（UIGF mihoyo-api-collect）吻合：client_type=4（网页）配 DS1 + LK2 salt，DS=md5("salt={LK2}&t={秒}&r={6位随机串}")，格式 "{t},{r},{md5}"。

## 实现
- 新增 net/DsSign.ets：cryptoFramework MD5；webDs1()（LK2/6位随机串）与 webDs2()（x6/6位随机整数，含排序 query，仅诊断对照用）。
- PostApi.webHeaders()：Chrome UA、Referer/Origin、Accept、Accept-Language、x-rpc 四元组（2.102.0 / 4 / DeviceIdentity.deviceId() / deviceFp()，ensureFp 先兜底）、可选 Ds、登录 Cookie；不再带 X-Requested-With。
- fetchPostFull：query 以 gids 在前组装（字母序，与 DS2 对照复用同一串），主请求 = webHeaders(query,'ds1')。
- 诊断按钮 → probeVariants 四变体对照（A 基线 / B 仅 x-rpc / C x-rpc+DS1 / D x-rpc+DS2），输出 retcode/message/data 有无，用于确认最小解锁组合。
- trace 改追加式（' | ' 连接，400 字符截断），中间证据不再被最后一跳覆盖。
- 只读原则不变：仅 GET；x-rpc 用网页身份（client_type=4），未引入官方 App 私有身份（Hyperion/2.117.0/client_type=5 仍只属于 MysHttp.buildHeaders 的既有调用方）。

## 验收
1. b147 真机打开 79139530：直接渲染正文、作者、评论区正常。
2. 旧帖（原神/星铁）回归正常，不触发额外请求。
3. 未登录、无 device_fp（首启 ensureFp 兜底）、未知 gid（不带 gids）路径不崩溃。

## 教训（工程规则，已同步 AGENTS.md）
- 诊断 trace 必须追加式累积：覆盖式只留最后一跳，b146 验证期曾因此把「新代码已生效但仍失败」误判为「装错包」，白走一轮卸载重装。
- URL 一致 ≠ 请求一致：对比必须落到完整 Request Headers（含 x-rpc/Ds/Accept-Language 这类非浏览器默认头）。
- 每个假设单独成变体、一次诊断全对照：A/B/C/D 同条件顺序输出，一次定位最小解锁集，避免逐轮 CI 盲猜。
