# 帖子原生交互：实现与验收

状态：代码实现，待构建与真机验收；不可标为已实测。频道系统上一轮已获用户验收。

- 正文/评论 PostText 和标题开启 CopyOptions.LocalDevice 与原生选区；选区范围在单个 Text 内，不承诺跨图片跨组件选区。
- PostContentModels 包装原 PostModels，保留旧解析降级；补结构化数组/ops、attributes.link、link_card 和 HTML href。只打开 HTTP(S)，使用隐式 viewData+browsable Want，遵循设备默认处理设置；不指定浏览器包名、不使用 App Linking 优先跳 App。
- 图片长按中心 CustomDialog：分享图片、保存到图库、取消。短按与长按互斥；全屏图仅追加长按手势，不增加图像节点、不修改 V5.1 飞行和透明度时序。
- 图片通过 MysHttp.imageBytes 下载，不携带会话/设备凭据，32 MiB 缓冲上限。按文件头识别 JPEG/PNG/GIF/WebP，暂不支持 HEIF/AVIF 的导出；不把未知数据伪装成 jpg。
- 保存使用 PhotoAccessHelper.showAssetsCreationDialog(srcUris, configs)，用户同意后还必须向返回 URI 写入数据；用户取消不提示成功。不申请整库读写权限。
- 分享使用 systemShare.SharedData 的 IMAGE URI，交给 ShareController。分享缓存不随面板立即删除，超过48小时在下次图片操作时清理；应用缓存也可由系统回收。
- 视频只按有公开依据的 data.post.vod_list[].resolutions[].url 取源，选最高码率；structured insert.vod 在原位置引用，未引用视频追加到末尾。没有地址显示不可播放；不猜 CDN、不绕过鉴权。
- 播放是 ArkUI 原生 Video/VideoController（不是外部图库播放器应用），用户点播放才挂载并启动，系统控制栏提供进度和全屏。离开可见区域暂停；地址失效/格式不支持时提示并可重试。

依据：
- https://uigf.org/zh/mihoyo-api-collection/hoyolab/article/article.html
- https://github.com/danbooru/danbooru/blob/master/app/logical/source/extractor/miyoushe.rb
- https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-apis-photoaccesshelper-photoaccesshelper
- https://developer.huawei.com/consumer/en/doc/harmonyos-guides/share-utd-image

验收：选字拖动与跨应用粘贴；普通网址/带标签超链接；未知协议不打开；图片长按不同时触发预览；分享接收的是图片；图库保存成功/取消/断网/大图/不支持格式；视频手动播放、进度、全屏、退出暂停、失败重试；回归图片开关无闪烁、缩放和系统返回，以及楼中楼。
