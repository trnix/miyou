// getPostReplies 评论模型与防御性解析。
// 只取主楼评论（楼中楼展开归 R6）；字段缺失不崩，list 缺失为空数组。

export interface ReplyItem {
  replyId: string;
  author: string;
  avatar: string;
  timeText: string;
  content: string;
  likeNum: number;
  subReplyCount: number;
}

export interface RepliesResult {
  retcode: number;
  message: string;
  replies: ReplyItem[];
  lastId: string;
  isLast: boolean;
}

function asStr(v: Object | undefined): string {
  if (typeof v === 'string') {
    return v;
  }
  return '';
}

function asNum(v: Object | undefined): number {
  if (typeof v === 'number') {
    return v;
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

export class ReplyModels {
  static parse(raw: Object): RepliesResult {
    const obj = raw as Record<string, Object>;
    const rc = obj['retcode'];
    const retcode = typeof rc === 'number' ? rc : -1;
    const message = asStr(obj['message']);
    const replies: ReplyItem[] = [];
    let lastId = '';
    let isLast = true;
    try {
      const data = obj['data'] as Record<string, Object> | undefined;
      if (data) {
        lastId = asStr(data['last_id']);
        const il = data['is_last'];
        isLast = typeof il === 'boolean' ? il : true;
        const list = data['list'];
        if (Array.isArray(list)) {
          (list as Object[]).forEach((item: Object) => {
            const it = item as Record<string, Object>;
            const reply = it['reply'] as Record<string, Object> | undefined;
            const user = it['user'] as Record<string, Object> | undefined;
            const rid = reply ? asStr(reply['reply_id']) : '';
            if (rid === '') {
              return;
            }
            replies.push({
              replyId: rid,
              author: user ? asStr(user['nickname']) : '',
              avatar: user ? asStr(user['avatar_url']) : '',
              timeText: relTime(reply ? asNum(reply['created_at']) : 0),
              content: reply ? asStr(reply['content']) : '',
              likeNum: reply ? asNum(reply['like_num']) : 0,
              subReplyCount: reply ? asNum(reply['sub_reply_count']) : 0
            });
          });
        }
      }
    } catch (e) {
      // 保留已解析部分
    }
    return { retcode, message, replies, lastId, isLast };
  }
}
