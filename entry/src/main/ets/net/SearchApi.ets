import { MysHttp } from './MysHttp';
import { PostContext } from './PostContext';

export interface SearchPost {
  id: string;
  title: string;
  author: string;
  excerpt: string;
  replies: number;
  likes: number;
}
export interface SearchResult {
  posts: SearchPost[];
  cursor: string;
  end: boolean;
}
function text(v: Object | undefined): string {
  return typeof v === 'string' ? v : '';
}
function num(v: Object | undefined): number {
  return typeof v === 'number' ? v : 0;
}
export class SearchApi {
  // 搜索返回中的post.game_id优先于当前选择频道；不把标题关键词当频道。
  static async search(gid: string, keyword: string, cursor: string, order: number): Promise<SearchResult> {
    const url = 'https://bbs-api.miyoushe.com/post/wapi/searchPosts' +
      `?gids=${encodeURIComponent(gid)}&keyword=${encodeURIComponent(keyword)}` +
      `&last_id=${encodeURIComponent(cursor)}&size=20&order_type=${order}`;
    const raw = await MysHttp.request(url, {
      'User-Agent': 'Mozilla/5.0',
      'Referer': 'https://www.miyoushe.com/',
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    });
    if (raw.httpCode !== 200) { throw new Error(`HTTP ${raw.httpCode}`); }
    const obj = JSON.parse(raw.body) as Record<string, Object>;
    if (obj['retcode'] !== 0) {
      throw new Error(`接口返回 ${num(obj['retcode'])}：${text(obj['message']).substring(0, 80)}`);
    }
    const data = obj['data'] as Record<string, Object> | undefined;
    if (!data || !Array.isArray(data['posts'])) { throw new Error('搜索响应结构不匹配：缺少 data.posts'); }
    PostContext.rememberLists(obj);
    const posts: SearchPost[] = [];
    const seen = new Set<string>();
    (data['posts'] as Object[]).forEach((entry: Object) => {
      try {
        if (!entry) { return; }
        const it = entry as Record<string, Object>;
        const p = it['post'] as Record<string, Object> | undefined;
        const u = it['user'] as Record<string, Object> | undefined;
        const s = it['stat'] as Record<string, Object> | undefined;
        const id = p ? text(p['post_id']) : '';
        if (id === '' || seen.has(id)) { return; }
        seen.add(id);
        posts.push({ id, title: p ? text(p['subject']) : '',
          author: u ? text(u['nickname']) : '',
          excerpt: p ? text(p['content']).replace(/<[^>]*>/g, '').substring(0, 160) : '',
          replies: s ? num(s['reply_num']) : 0, likes: s ? num(s['like_num']) : 0 });
      } catch (e) {
        // 跳过单条损坏数据。
      }
    });
    const source = data['posts'] as Object[];
    if (source.length > 0 && posts.length === 0) { throw new Error('搜索返回非空列表，但帖子字段无法识别'); }
    const next = text(data['last_id']);
    return { posts, cursor: next, end: data['is_last'] === true || source.length === 0 || next === '' || next === cursor };
  }
}
