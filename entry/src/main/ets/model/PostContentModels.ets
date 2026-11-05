import { PostModels, PostDetail, PostBlock } from './PostModels';

export interface TextRun { text: string; url: string; }
export interface ContentBlock extends PostBlock { runs: TextRun[]; videoUrl: string; }
export interface RichPostDetail extends PostDetail { blocks: ContentBlock[]; }

export function webUrl(value: string): string {
  let s = value.trim();
  if (s.startsWith('//')) { s = 'https:' + s; }
  if (s.startsWith('www.')) { s = 'https://' + s; }
  return /^https?:\/\/[^\s/?#]+[^\s]*$/i.test(s) && !/[\u0000-\u001f\u007f]/.test(s) ? s : '';
}

export function linkRuns(text: string): TextRun[] {
  const out: TextRun[] = [];
  const re = /(?:https?:\/\/|www\.)[^\s<>"'，。；！？、）】]+/gi;
  let at = 0;
  let match = re.exec(text);
  while (match !== null) {
    const token = match[0].replace(/[.,;!?]+$/, '');
    if (match.index > at) { out.push({ text: text.substring(at, match.index), url: '' }); }
    out.push({ text: token, url: webUrl(token) });
    at = match.index + token.length;
    match = re.exec(text);
  }
  if (at < text.length) { out.push({ text: text.substring(at), url: '' }); }
  return out;
}

function str(v: Object | undefined): string { return typeof v === 'string' ? v : ''; }
function obj(v: Object | undefined): Record<string, Object> {
  if (v !== null && typeof v === 'object' && !Array.isArray(v)) { return v as Record<string, Object>; }
  return {};
}
function arr(v: Object | undefined): Object[] { return Array.isArray(v) ? v as Object[] : []; }

// 数组型Delta规范化为有明确类型的{ops:数组}，不能交给obj()直接丢弃。
// 返回值仍是Record，避免Object上下文中的未定型空字面量。
function parsed(v: Object | undefined): Record<string, Object> {
  let value: Object | undefined = v;
  if (typeof v === 'string') {
    try { value = JSON.parse(v) as Object; } catch (e) { return {}; }
  }
  if (Array.isArray(value)) {
    const normalized: Record<string, Object> = { ops: value as Object[] };
    return normalized;
  }
  return obj(value);
}
function block(kind: string, text: string = '', imageUrl: string = '', runs: TextRun[] = [], videoUrl: string = ''): ContentBlock {
  return { kind, text, imageUrl, runs, videoUrl };
}
function flush(out: ContentBlock[], runs: TextRun[]): void {
  const text = runs.map((r: TextRun) => r.text).join('');
  if (text.trim() !== '') { out.push(block('text', text, '', runs.slice())); }
  runs.length = 0;
}
function entities(text: string): string {
  return text.replace(/&nbsp;/gi, ' ').replace(/&quot;|&#34;/gi, '"')
    .replace(/&#39;|&#039;|&#x27;/gi, "'").replace(/&lt;/gi, '<').replace(/&gt;/gi, '>').replace(/&amp;/gi, '&');
}
function plain(html: string): string {
  return entities(html.replace(/<script\b[^>]*>[\s\S]*?<\/script\s*>/gi, '')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style\s*>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n').replace(/<\/(p|div|li|h[1-6])\s*>/gi, '\n\n').replace(/<[^>]*>/g, ''));
}
function attr(tag: string, key: string): string {
  const m = new RegExp('\\b' + key + '\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s>]+))', 'i').exec(tag);
  return m === null ? '' : entities(m[1] || m[2] || m[3] || '');
}

function htmlBlocks(html: string): ContentBlock[] {
  const out: ContentBlock[] = [];
  const runs: TextRun[] = [];
  const safe = html.replace(/<script\b[^>]*>[\s\S]*?<\/script\s*>/gi, '')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style\s*>/gi, '');
  const re = /<img\b[^>]*>|<a\b[^>]*>[\s\S]*?<\/a\s*>/gi;
  let at = 0;
  let m = re.exec(safe);
  while (m !== null) {
    runs.push(...linkRuns(plain(safe.substring(at, m.index))));
    const token = m[0];
    if (/^<img/i.test(token)) {
      flush(out, runs);
      const src = webUrl(attr(token, 'src'));
      if (src !== '') { out.push(block('image', '', src)); }
    } else {
      const end = token.indexOf('>');
      const url = webUrl(attr(token.substring(0, end + 1), 'href'));
      const label = plain(token.substring(end + 1).replace(/<\/a\s*>$/i, ''));
      runs.push({ text: label || url, url });
    }
    at = m.index + token.length;
    m = re.exec(safe);
  }
  runs.push(...linkRuns(plain(safe.substring(at))));
  flush(out, runs);
  return out;
}

function videoBlock(v: Object): ContentBlock {
  const item = obj(v);
  let source = '';
  let best = -1;
  arr(item['resolutions']).forEach((entry: Object) => {
    const r = obj(entry);
    const url = webUrl(str(r['url']));
    const score = Number(r['bitrate']) || Number(r['height']) || 0;
    if (url !== '' && score > best) { source = url; best = score; }
  });
  return block('video', '', webUrl(str(item['cover'])), [], source);
}

export class PostContentModels {
  static parseDetail(raw: Object, postId: string): RichPostDetail {
    const base = PostModels.parseDetail(raw, postId);
    const wrap = obj(obj(raw)['data']);
    const article = obj(wrap['post']);
    const post = obj(article['post']);
    const videos = arr(article['vod_list']);
    const used = new Set<number>();
    let blocks: ContentBlock[] = base.blocks.map((b: PostBlock) => block(b.kind, b.text, b.imageUrl, linkRuns(b.text)));
    try {
      const structured = parsed(post['structured_content']);
      const ops = arr(structured['ops']);
      if (ops.length > 0) {
        const out: ContentBlock[] = [];
        const runs: TextRun[] = [];
        ops.forEach((entry: Object) => {
          const op = obj(entry);
          const insert = op['insert'];
          if (typeof insert === 'string') {
            const target = webUrl(str(obj(op['attributes'])['link']));
            if (target !== '') { runs.push({ text: insert, url: target }); }
            else { runs.push(...linkRuns(insert)); }
          } else {
            const embed = obj(insert);
            flush(out, runs);
            if (embed['image'] !== undefined) {
              const value = str(embed['image']);
              let url = webUrl(value);
              if (url === '') {
                arr(article['image_list']).forEach((image: Object) => {
                  const item = obj(image);
                  if (String(item['image_id']) === value) { url = webUrl(str(item['url'])); }
                });
              }
              if (url !== '') { out.push(block('image', '', url)); }
              else { out.push(block('unknown')); }
            } else if (embed['vod'] !== undefined) {
              const value = embed['vod'];
              const id = typeof value === 'string' || typeof value === 'number' ? String(value) : str(obj(value)['id']);
              let index = videos.findIndex((video: Object) => String(obj(video)['id']) === id);
              if (index < 0 && videos.length === 1) { index = 0; }
              if (index >= 0) { out.push(videoBlock(videos[index])); used.add(index); }
              else { out.push(block('video')); }
            } else if (embed['link_card'] !== undefined) {
              const card = obj(embed['link_card']);
              const target = webUrl(str(card['landing_url'])) || webUrl(str(card['origin_url']));
              const title = str(card['title']) || target;
              if (title !== '') { out.push(block('text', title, '', [{ text: title, url: target }])); }
            } else { out.push(block('unknown')); }
          }
        });
        flush(out, runs);
        if (out.length > 0) { blocks = out; }
      } else if (/<a\b/i.test(base.contentText)) {
        const html = htmlBlocks(base.contentText);
        if (html.length > 0) { blocks = html; }
      }
    } catch (e) {
      // 富文本增强失败时保留原解析结果。
    }
    videos.forEach((v: Object, i: number) => { if (!used.has(i)) { blocks.push(videoBlock(v)); } });
    return {
      retcode: base.retcode, message: base.message, postId: base.postId, title: base.title, contentText: base.contentText,
      author: base.author, authorUid: base.authorUid, avatar: base.avatar, timeText: base.timeText,
      forumName: base.forumName, isOfficial: base.isOfficial, topics: base.topics,
      viewNum: base.viewNum, replyNum: base.replyNum, likeNum: base.likeNum, blocks
    };
  }
}
