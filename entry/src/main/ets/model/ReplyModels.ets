// getPostReplies 评论模型与防御性解析。
// 只取主楼评论（楼中楼展开归 R6）；字段缺失不崩，list 缺失为空数组。
// content 可能是纯文本、HTML，或内嵌 JSON（图片/表情包），统一提取为纯文本 + 图片列表。

export interface ReplyItem {
  replyId: string;
  authorUid: string;
  author: string;
  avatar: string;
  timeText: string;
  content: string;
  images: string[];
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

interface ExtractedContent {
  text: string;
  images: string[];
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

// 从评论 content 提取纯文本与图片 URL；content 形态：纯文本 / HTML / JSON 字符串
function extractContent(raw: string): ExtractedContent {
  const images: string[] = [];
  let text = raw.trim();
  if (text.startsWith('{') && text.endsWith('}')) {
    try {
      const obj = JSON.parse(text) as Record<string, Object>;
      const desc = asStr(obj['describe']);
      if (desc !== '') {
        text = desc;
      }
      const imgs = obj['imgs'];
      if (Array.isArray(imgs)) {
        (imgs as Object[]).forEach((iv: Object) => {
          let u = '';
          if (typeof iv === 'string') {
            u = iv;
          } else if (typeof iv === 'object' && iv !== null) {
            u = asStr((iv as Record<string, Object>)['url']);
          }
          if (u !== '') {
            images.push(u);
          }
        });
      }
      return { text: text.trim(), images };
    } catch (e) {
      // 不是合法 JSON，按原文处理
    }
  }
  if (text.indexOf('<') >= 0 && text.indexOf('>') >= 0) {
    let rest = text;
    let out = '';
    while (rest.length > 0) {
      const imgIdx = rest.indexOf('<img');
      if (imgIdx < 0) {
        out += rest.replace(/<[^>]*>/g, '');
        break;
      }
      out += rest.substring(0, imgIdx).replace(/<[^>]*>/g, '');
      const tagEnd = rest.indexOf('>', imgIdx);
      if (tagEnd < 0) {
        break;
      }
      const tag = rest.substring(imgIdx, tagEnd);
      const srcIdx = tag.indexOf('src="');
      if (srcIdx >= 0) {
        const q1 = srcIdx + 5;
        const q2 = tag.indexOf('"', q1);
        if (q2 > q1) {
          images.push(tag.substring(q1, q2));
        }
      }
      rest = rest.substring(tagEnd + 1);
    }
    text = out.replace(/<[^>]*>/g, '').trim();
  }
  return { text, images };
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
            const extracted = extractContent(reply ? asStr(reply['content']) : '');
            replies.push({
              replyId: rid,
              authorUid: user ? asStr(user['uid']) : '',
              author: user ? asStr(user['nickname']) : '',
              avatar: user ? asStr(user['avatar_url']) : '',
              timeText: relTime(reply ? asNum(reply['created_at']) : 0),
              content: extracted.text,
              images: extracted.images,
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
