// 消息中心模型与防御性解析。
// 消息接口无公开文档，端点为推测候选；解析对字段嵌套/平铺两态均做防御，
// 并保留 body 截断（rawPreview）供页面诊断卡展示，便于真机校准端点。

export interface MessageCnt {
  replyAt: number;
  praise: number;
  follow: number;
  total: number;
}

export interface NotifyItem {
  id: string;
  nickname: string;
  avatar: string;
  content: string;
  timeText: string;
  postId: string;
  isNew: boolean;
}

export interface NotifyListResult {
  retcode: number;
  message: string;
  items: NotifyItem[];
  lastId: string;
  isLast: boolean;
}

function asStr(v: Object | undefined): string {
  if (typeof v === 'string') {
    return v;
  }
  if (typeof v === 'number') {
    return v.toString();
  }
  return '';
}

function asNum(v: Object | undefined): number {
  if (typeof v === 'number') {
    return v;
  }
  if (typeof v === 'string') {
    const n = Number(v);
    return isNaN(n) ? 0 : n;
  }
  return 0;
}

function relTime(ts: number): string {
  if (ts <= 0) {
    return '';
  }
  const diff = Date.now() / 1000 - ts;
  if (diff < 3600) {
    const m = Math.max(1, Math.floor(diff / 60));
    return m + '分钟前';
  }
  if (diff < 86400) {
    return Math.floor(diff / 3600) + '小时前';
  }
  const d = new Date(ts * 1000);
  const mm = (d.getMonth() + 1).toString().padStart(2, '0');
  const dd = d.getDate().toString().padStart(2, '0');
  return `${mm}-${dd}`;
}

// 从多个候选键中取第一个非空字符串。
function pickStr(obj: Record<string, Object>, keys: string[]): string {
  for (let i = 0; i < keys.length; i++) {
    const v = asStr(obj[keys[i]]);
    if (v !== '') {
      return v;
    }
  }
  return '';
}

export class NotifyModels {
  static parseCnt(body: string): MessageCnt {
    const zero: MessageCnt = { replyAt: 0, praise: 0, follow: 0, total: 0 };
    try {
      const obj = JSON.parse(body) as Record<string, Object>;
      const data = obj['data'] as Record<string, Object> | undefined;
      if (!data) {
        return zero;
      }
      const replyAt = asNum(data['reply_at_cnt']);
      const praise = asNum(data['praise_cnt']);
      const follow = asNum(data['follow_cnt']);
      return { replyAt, praise, follow, total: replyAt + praise + follow };
    } catch (e) {
      return zero;
    }
  }

  static parseList(body: string): NotifyListResult {
    let retcode = -1;
    let message = '';
    const items: NotifyItem[] = [];
    let lastId = '';
    let isLast = true;
    try {
      const obj = JSON.parse(body) as Record<string, Object>;
      const rc = obj['retcode'];
      retcode = typeof rc === 'number' ? rc : -1;
      message = asStr(obj['message']);
      const data = obj['data'] as Record<string, Object> | undefined;
      if (data) {
        lastId = asStr(data['last_id']);
        const il = data['is_last'];
        isLast = typeof il === 'boolean' ? il : true;
        const list = data['list'];
        if (Array.isArray(list)) {
          (list as Object[]).forEach((raw: Object) => {
            const it = raw as Record<string, Object>;
            // 用户字段：嵌套 user 优先，平铺兜底。
            const user = it['user'] as Record<string, Object> | undefined;
            const nickname = user ? pickStr(user, ['nickname', 'name']) : pickStr(it, ['nickname', 'from_nickname']);
            const avatar = user ? asStr(user['avatar_url']) : pickStr(it, ['avatar_url', 'from_avatar_url']);
            const content = pickStr(it, ['content', 'reply_content', 'desc', 'title', 'notify_content']);
            const id = pickStr(it, ['notify_id', 'id', 'reply_id']);
            const postId = pickStr(it, ['post_id', 'entity_id']);
            const ts = asNum(it['created_at']);
            const ir = it['is_read'];
            const isNew = typeof ir === 'boolean' ? !ir : false;
            items.push({
              id: id !== '' ? id : `${postId}-${ts}`,
              nickname, avatar, content,
              timeText: relTime(ts),
              postId, isNew
            });
          });
        }
      }
    } catch (e) {
      // 保留已解析部分
    }
    return { retcode, message, items, lastId, isLast };
  }
}
