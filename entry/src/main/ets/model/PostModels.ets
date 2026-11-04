// getPostFull 帖子详情模型与防御性解析。
// 正文归一为 text / image / unknown 三种块；四种结构形态（NORMAL/PIC/UGC/VOD）各自归一化；
// structured_content 缺失时 post.content 可能是 HTML 或 JSON 字符串（用户帖常见），分别走对应解析。
// 未知块、解析失败、字段缺失一律降级，绝不崩溃。
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

// 段落语义：空行（连续换行）为段落分隔，段内单换行保留为 Text 内换行。
// 与「每行一块」的区别：同段各行不会被硬拆开，行距正常；段落之间由页面 Column 间距拉开。
function pushParagraphs(blocks: PostBlock[], text: string): void {
  const normalized = text.replace(/\r\n/g, '\n');
  const paras = normalized.split(/\n{2,}/);
  paras.forEach((p: string) => {
    const t = p.trim();
    if (t !== '') {
      blocks.push(textBlock(t));
    }
  });
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
// Quill 惯例每行一个 op 且尾部带 \n，空行为独立 '\n' op——先按序拼接完整文本，再按空行切分段落。
function parseDelta(sc: Record<string, Object>): PostBlock[] {
  const blocks: PostBlock[] = [];
  const ops = sc['ops'];
  if (!Array.isArray(ops)) {
    return blocks;
  }
  let pending = '';
  (ops as Object[]).forEach((op: Object) => {
    const o = op as Record<string, Object>;
    const ins = o['insert'];
    if (typeof ins === 'string') {
      pending += ins;
    } else if (typeof ins === 'object' && ins !== null) {
      const io = ins as Record<string, Object>;
      const img = asStr(io['image']);
      pushParagraphs(blocks, pending);
      pending = '';
      if (img !== '') {
        blocks.push(imageBlock(img));
      } else {
        blocks.push({ kind: 'unknown', text: '', imageUrl: '' });
      }
    }
  });
  pushParagraphs(blocks, pending);
  return blocks;
}

// PIC：describe 文本 + imgs[] 数组（元素可能是字符串 URL 或 {url} 对象）
function parsePic(sc: Record<string, Object>): PostBlock[] {
  const blocks: PostBlock[] = [];
  const desc = asStr(sc['describe']);
  if (desc.trim() !== '') {
    pushParagraphs(blocks, desc.trim());
  }
  const imgs = sc['imgs'];
  if (Array.isArray(imgs)) {
    (imgs as Object[]).forEach((iv: Object) => {
      let u = '';
      if (typeof iv === 'string') {
        u = iv;
      } else if (typeof iv === 'object' && iv !== null) {
        u = asStr((iv as Record<string, Object>)['url']);
      }
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
    pushParagraphs(blocks, text.trim());
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

// HTML 兜底：提取 <img src> 为图片块，其余剥标签换行为文字块。
function decodeEntities(s: string): string {
  return s
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, '\'')
    .replace(/&#x27;/g, '\'');
}

function htmlToText(s: string): string {
  const withBreaks = s
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/div>/gi, '\n\n');
  return decodeEntities(withBreaks.replace(/<[^>]*>/g, '')).trim();
}

function parseHtml(html: string): PostBlock[] {
  const blocks: PostBlock[] = [];
  let rest = html;
  while (rest.length > 0) {
    const imgIdx = rest.indexOf('<img');
    if (imgIdx < 0) {
      pushParagraphs(blocks, htmlToText(rest));
      break;
    }
    pushParagraphs(blocks, htmlToText(rest.substring(0, imgIdx)));
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
        blocks.push(imageBlock(tag.substring(q1, q2)));
      }
    }
    rest = rest.substring(tagEnd + 1);
  }
  return blocks;
}

// post.content 为 JSON 字符串时的解析（用户帖常见形态）：结构与 parsePic 相同。
function parseJsonContent(content: string): PostBlock[] {
  const blocks: PostBlock[] = [];
  try {
    const obj = JSON.parse(content) as Record<string, Object>;
    const desc = asStr(obj['describe']);
    if (desc !== '') {
      pushParagraphs(blocks, desc);
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
          blocks.push(imageBlock(u));
        }
      });
    }
    // 兼容 text/images 形态
    const text = asStr(obj['text']);
    if (blocks.length === 0 && text !== '') {
      pushParagraphs(blocks, text);
    }
    const images = obj['images'];
    if (Array.isArray(images)) {
      (images as Object[]).forEach((iv: Object) => {
        const u = asStr((iv as Record<string, Object>)['url']);
        if (u !== '') {
          blocks.push(imageBlock(u));
        }
      });
    }
  } catch (e) {
    // 不是合法 JSON，返回空由调用方按纯文本处理
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

        // 结构化正文归一：structured_content 可能是字符串（需先 JSON.parse）或对象
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
          if (sc['ops'] !== undefined) {
            blocks = parseDelta(sc);
          } else if (sc['imgs'] !== undefined) {
            blocks = parsePic(sc);
          } else if (sc['images'] !== undefined) {
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
      // 整体解析失败时保留已提取字段，blocks 走下方兜底
    }

    // 结构化解析未产出块时：content 按 JSON / HTML / 纯文本三种形态分别处理
    if (blocks.length === 0 && contentText.trim() !== '') {
      const trimmed = contentText.trim();
      if (trimmed.startsWith('{')) {
        blocks = parseJsonContent(trimmed);
      }
      if (blocks.length === 0 && contentText.indexOf('<') >= 0 && contentText.indexOf('>') >= 0) {
        blocks = parseHtml(contentText);
      }
      if (blocks.length === 0) {
        pushParagraphs(blocks, trimmed);
      }
    }

    return {
      retcode, message, postId: postId2, title, contentText,
      author, avatar, timeText, forumName, isOfficial,
      topics, viewNum, replyNum, likeNum, blocks
    };
  }
}
