# getSemPosts 条件回退补丁

状态：待CI编译及真机验证，不标为已修复。

## 依据
用户对79139530的设备诊断显示：旧getPostFull三种read写法均HTTP200、retcode=-1、data=null、message包含升级。
官方网页F12成功请求实际为 painter/wapi/getSemPosts?gids=8&post_id=79139530，返回结构data.post.post。上传样本中的structured_content是JSON数组，拼接insert字符串与content.describe一致。
这些证据证明存在已观察到的另一读取路径，不证明所有帖子都需要它，也不证明单个请求头或Cookie是原因。截图凭据不得存档。

## 实现
- 正常getPostFull成功保持原流程；只对retcode=-1、空data、升级提示回退一次getSemPosts。HTTP错误、其它业务错误不自动切接口。
- 复用米柚自身既有请求头及会话，不复制浏览器Cookie、token或设备指纹。
- PostContext按帖子ID保存响应中的post.game_id，缺失时看forum.game_id；不依据搜索词或当前全局选择推断。只在内存保存，最多2048条。
- 搜索posts、首页fixed_posts/recommended_posts、用户主页list均接入记录；成功详情刷新映射。未知频道不扫描或猜测；没有真实game_id时保留原错误。
- 对成功详情校验返回post_id，防止错帖；楼中楼优先使用记录的真实频道而不是旧调用处固定2。
- 数组Delta包成具名Record上下文的{ops:数组}，不再被obj()丢弃；对象型{ops:[]}照旧。
- 原诊断按钮不变；接口诊断回执追加最近详情加载路径摘要，包括getSemPosts的HTTP和业务码，不记录请求头/Cookie/响应头。诊断任意URL入口增加官方白名单。
- 不改页面布局、V5.1图片预览、版本0.8.0及搜索胶囊样式。

## 验收
1. 同词跨频道搜索后，79139530正确打开且标题、正文、作者匹配。
2. 原神旧帖正常打开；不触发无条件双请求。
3. 新接口403、业务失败、成功但ID不匹配、未知频道均不假报成功。
4. 数组Delta、对象ops、纯describe降级、链接和视频回归。
5. 非原神楼中楼、首页入口、用户主页入口回归。
6. 若仍失败，复制诊断摘要确认实际频道和getSemPosts回执；不能宣称浏览器实测等于App实测。
