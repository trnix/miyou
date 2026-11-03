# R6 帖子搜索第一阶段

状态：代码待提交、CI 与真机待验收；不能标记功能完成。

## 实现范围

- 临时入口：社区 tab。保留首页信息流；独立搜索页面与首页入口留后续整合。
- 原神(2)、星穹铁道(6)、绝区零(8)，最热(1)/最新(2)。
- 手动分页、ID 去重、游标不推进时停止分页、旧请求响应隔离。
- 业务失败、结构不匹配、网络失败均不显示为空结果。
- 当前结果卡展示标题、作者、纯文本摘要与互动数；不含图片预览和用户主页跳转。

## 接口证据

上游 BTMuli/TeyvatGuide：src/request/postReq.ts searchPosts；src/types/BBS/Post.d.ts SearchRes。
GET /post/wapi/searchPosts：gids、keyword、last_id、size、order_type。
响应 data.posts、data.last_id、data.is_last。上游源码存在不等于当前服务已验证可用。

## 验收

中文关键词、三频道、两种排序、分页去重、空结果、断网重试、快速搜索竞态、点击进入详情、底栏遮挡检查。

## R4/R5 结论纠偏

继续按用户决定搁置，不重新尝试。已观测到 getGameRecordCard 的测试请求返回 -10001，而 bbs 用户态请求返回 0；这不足以证明设备指纹封禁、DS 全面失效或所有便签接口不可用。蓝图 v1.11 的绝对归因不作为已证实技术结论。
前次 push_files 仅清理入口和路由，并未删除 QrLoginApi/QrLogin/RecordApi 文件；后续实际删除必须独立核验与审批。
