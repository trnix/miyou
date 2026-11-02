// getPostFull 帖子详情模型与防御性解析。
// 正文归一为 text / image / unknown 三种块；四种结构形态（NORMAL/PIC/UGC/VOD）各自归一化；
// 未知块、解析失败、字段缺失一律降级，绝不崩溃——解析失败的兜底是纯文本 post.content。
// 注意：ArkTS 禁止索引访问类型，断言后取键必须写成 (x as Record<string, Object>)['key']。

export interface PostBlock {
  kind: string; // 'text' | 'image' | 'unknown'
  text: string;
  imageUrl: string;
}

export interface PostDetail {
  retcode: number;
  message: string;
  postId: string;
  title: string;
  contentText: string;
  author: string;
  avatar: string;
  timeText: string;
  forumName: string;
  isOfficial: boolean;
  topics: string[];
  viewNum: number;
  replyNum: number;
  likeNum: number;
  blocks: PostBlock[];
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

function asBool(v: Object | undefined): boolean {
  if (typeof v === 'boolean') {
    return v;
  }
  return false;
}

function textBlock(t: string): PostBlock {
  return { kind: 'text', text: t, imageUrl: '' };
}

function imageBlock(url: string): PostBlock {
  return { kind: 'image', text: '', imageUrl: url };
}

function timeTextOf(ts: number): string {
  if (ts <= 0) {
    return '';
  }
  const d = new Date(ts * 1000);
  const mm = (d.getMonth() + 1).toString().padStart(2, '0');
  const dd = d.getDate().toString().padStart(2, '0');
  const hh = d.getHours().toString().padStart(2, '0');
  const mi = d.getMinutes().toString().padStart(2, '0');
  return `${mm}-${dd} ${hh}:${mi}`;
}

// NORMAL（Quill-delta 风格）：{ insert: '...' } / { insert: { image: url } }
function parseDelta(sc: Record<string, Object>): PostBlock[] {
  const blocks: PostBlock[] = [];
  const ops = sc['ops'];
  if (!Array.isArray(ops)) {
    return blocks;
  }
  (ops as Object[]).forEach((op: Object) => {
    const o = op as Record<string, Object>;
    const ins = o['insert'];
    if (typeof ins === 'string') {
      const t = ins.trim();
      if (t !== '') {
        blocks.push(textBlock(t));
      }
    } else if (typeof ins === 'object' && ins !== null) {
      const io = ins as Record<string, Object>;
      const img = asStr(io['image']);
      if (img !== '') {
        blocks.push(imageBlock(img));
      } else {
        blocks.push({ kind: 'unknown', text: '', imageUrl: '' });
      }
    }
  });
  return blocks;
}

// PIC：describe 文本 + imgs[] 数组
function parsePic(sc: Record<string, Object>): PostBlock[] {
  const blocks: PostBlock[] = [];
  const desc = asStr(sc['describe']);
  if (desc.trim() !== '') {
    blocks.push(textBlock(desc.trim()));
  }
  const imgs = sc['imgs'];
  if (Array.isArray(imgs)) {
    (imgs as Object[]).forEach((iv: Object) => {
      const u = asStr((iv as Record<string, Object>)['url']);
      if (u !== '') {
        blocks.push(imageBlock(u));
      }
    });
  }
  return blocks;
}

// UGC：text/images/vods 数组按序
function parseUgc(sc: Record<string, Object>): PostBlock[] {
  const blocks: PostBlock[] = [];
  const text = asStr(sc['text']);
  if (text.trim() !== '') {
    blocks.push(textBlock(text.trim()));
  }
  const imgs = sc['images'];
  if (Array.isArray(imgs)) {
    (imgs as Object[]).forEach((iv: Object) => {
      const u = asStr((iv as Record<string, Object>)['url']);
      if (u !== '') {
        blocks.push(imageBlock(u));
      }
    });
  }
  return blocks;
}

export class PostModels {
  static parseDetail(raw: Object, postId: string): PostDetail {
    const obj = raw as Record<string, Object>;
    const rc = obj['retcode'];
    const retcode = typeof rc === 'number' ? rc : -1;
    const message = asStr(obj['message']);

    let postId2 = postId;
    let title = '';
    let contentText = '';
    let author = '';
    let avatar = '';
    let timeText = '';
    let forumName = '';
    let isOfficial = false;
    let topics: string[] = [];
    let viewNum = 0;
    let replyNum = 0;
    let likeNum = 0;
    let blocks: PostBlock[] = [];

    try {
      const data = obj['data'] as Record<string, Object> | undefined;
      const wrap = data ? data['post'] as Record<string, Object> | undefined : undefined;
      const post = wrap ? wrap['post'] as Record<string, Object> | undefined : undefined;
      const user = wrap ? wrap['user'] as Record<string, Object> | undefined : undefined;
      const stat = wrap ? wrap['stat'] as Record<string, Object> | undefined : undefined;
      const forum = wrap ? wrap['forum'] as Record<string, Object> | undefined : undefined;

      if (post) {
        postId2 = asStr(post['post_id']);
        title = asStr(post['subject']);
        contentText = asStr(post['content']);
        timeText = timeTextOf(asNum(post['created_at']));
        const st = post['post_status'] as Record<string, Object> | undefined;
        isOfficial = st ? asBool(st['is_official']) : false;

        // 结构化正文归一
        const scRaw = post['structured_content'];
        let sc: Record<string, Object> | null = null;
        if (typeof scRaw === 'string' && scRaw.trim() !== '') {
          try {
            sc = JSON.parse(scRaw) as Record<string, Object>;
          } catch (e) {
            sc = null;
          }
        } else if (typeof scRaw === 'object' && scRaw !== null) {
          sc = scRaw as Record<string, Object>;
        }
        if (sc !== null) {
          const viewType = asStr(sc['view_type']);
          if (viewType === 'VIEW_TYPE_NORMAL' || sc['ops'] !== undefined) {
            blocks = parseDelta(sc);
          } else if (viewType === 'VIEW_TYPE_PIC' || sc['imgs'] !== undefined) {
            blocks = parsePic(sc);
          } else if (viewType === 'VIEW_TYPE_UGC' || sc['images'] !== undefined) {
            blocks = parseUgc(sc);
          }
        }
      }
      if (user) {
        author = asStr(user['nickname']);
        avatar = asStr(user['avatar_url']);
      }
      if (forum) {
        forumName = asStr(forum['name']);
      }
      if (stat) {
        viewNum = asNum(stat['view_num']);
        replyNum = asNum(stat['reply_num']);
        likeNum = asNum(stat['like_num']);
      }
      const topicArr = wrap ? wrap['topics'] : undefined;
      if (Array.isArray(topicArr)) {
        const ts: string[] = [];
        (topicArr as Object[]).forEach((tv: Object) => {
          const n = asStr((tv as Record<string, Object>)['name']);
          if (n !== '') {
            ts.push(n);
          }
        });
        topics = ts;
      }
    } catch (e) {
      // 整体解析失败时保留已提取字段，blocks 走下方纯文本兜底
    }

    // 结构化解析未产出任何块时，用纯文本正文兜底
    if (blocks.length === 0 && contentText.trim() !== '') {
      blocks.push(textBlock(contentText.trim()));
    }

    return {
      retcode, message, postId: postId2, title, contentText,
      author, avatar, timeText, forumName, isOfficial,
      topics, viewNum, replyNum, likeNum, blocks
    };
  }
}
