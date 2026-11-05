import { MysHttp } from './MysHttp';
import { Session } from '../auth/Session';
import { PostContext } from './PostContext';

export interface PostProbe { url: string; httpCode: number; bodyExcerpt: string; }

export class PostApi {
  private static traces: Map<string, string> = new Map<string, string>();

  private static headers(): Record<string, string> {
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      'Referer': 'https://www.miyoushe.com/', 'Origin': 'https://www.miyoushe.com',
      'X-Requested-With': 'XMLHttpRequest', 'Accept': 'application/json, text/plain, */*'
    };
    const cookie = Session.cookie();
    if (cookie.length > 0) { headers['Cookie'] = cookie; }
    return headers;
  }

  private static trace(id: string, text: string): void {
    PostApi.traces.delete(id);
    PostApi.traces.set(id, text);
    if (PostApi.traces.size > 16) {
      const keys: string[] = Array.from(PostApi.traces.keys());
      PostApi.traces.delete(keys[0]);
    }
  }

  private static async doProbe(url: string): Promise<PostProbe> {
    try {
      const raw = await MysHttp.request(url, PostApi.headers());
      return { url, httpCode: raw.httpCode, bodyExcerpt: raw.body.substring(0, 3000) };
    } catch (e) {
      return { url, httpCode: 0, bodyExcerpt: '(请求异常，未获得HTTP响应)' };
    }
  }

  static async probeQuery(query: string): Promise<PostProbe> {
    const probe = await PostApi.doProbe('https://bbs-api.miyoushe.com/post/wapi/getPostFull?' + query);
    const match = /(?:^|&)post_id=(\d+)(?:&|$)/.exec(query);
    if (match !== null) {
      const trace = PostApi.traces.get(match[1]);
      if (trace !== undefined) { probe.bodyExcerpt += '\n[最近详情加载路径] ' + trace; }
    }
    return probe;
  }

  // 诊断仅限已使用的官方接口或文章页，禁止向任意域发送当前会话。
  static async probeUrl(url: string): Promise<PostProbe> {
    if (!/^https:\/\/www\.miyoushe\.com\/(zzz|ys)\/article\/\d+$/.test(url) &&
      !/^https:\/\/bbs-api\.miyoushe\.com\/painter\/wapi\/getSemPosts\?gids=\d+&post_id=\d+$/.test(url)) {
      return { url: '(不允许的诊断地址)', httpCode: 0, bodyExcerpt: '诊断地址必须在官方白名单内' };
    }
    return PostApi.doProbe(url);
  }

  static async fetchPostFull(postId: string): Promise<Object> {
    const id = encodeURIComponent(postId);
    PostApi.trace(postId, 'getPostFull 请求中');
    const raw = await MysHttp.request(`https://bbs-api.miyoushe.com/post/wapi/getPostFull?post_id=${id}&read=1`, PostApi.headers());
    PostApi.trace(postId, `getPostFull HTTP ${raw.httpCode}`);
    if (raw.httpCode !== 200) { throw new Error(`HTTP ${raw.httpCode}`); }
    const original = JSON.parse(raw.body) as Record<string, Object>;
    const rc = original['retcode'];
    const value = original['message'];
    const msg = typeof value === 'string' ? value : '';
    PostApi.trace(postId, `getPostFull HTTP 200, retcode=${typeof rc === 'number' ? rc : '缺失'}`);
    if (rc === 0) {
      if (!PostContext.matchesDetail(original, postId)) { throw new Error('详情返回的帖子ID不匹配'); }
      PostContext.rememberDetail(original);
      return original;
    }
    // 仅回退本次观测到的明确业务错误，不对403、鉴权失败或其它错误盲目重试。
    if (rc !== -1 || msg.indexOf('升级') < 0 || (original['data'] !== null && original['data'] !== undefined)) {
      return original;
    }
    const gid = PostContext.gameOf(postId);
    if (gid <= 0) {
      PostApi.trace(postId, 'getPostFull retcode=-1；没有该帖的真实game_id，未猜测频道或扫描接口');
      return original;
    }
    const url = `https://bbs-api.miyoushe.com/painter/wapi/getSemPosts?gids=${gid}&post_id=${id}`;
    PostApi.trace(postId, `getPostFull retcode=-1 → getSemPosts(gids=${gid}) 请求中`);
    const fallback = await MysHttp.request(url, PostApi.headers());
    PostApi.trace(postId, `getPostFull retcode=-1 → getSemPosts(gids=${gid}) HTTP ${fallback.httpCode}`);
    if (fallback.httpCode !== 200) { throw new Error(`getSemPosts HTTP ${fallback.httpCode}`); }
    const result = JSON.parse(fallback.body) as Record<string, Object>;
    const resultCode = result['retcode'];
    PostApi.trace(postId, `getPostFull retcode=-1 → getSemPosts(gids=${gid}) HTTP 200, retcode=${typeof resultCode === 'number' ? resultCode : '缺失'}`);
    if (resultCode === 0) {
      if (!PostContext.matchesDetail(result, postId)) {
        PostApi.trace(postId, 'getSemPosts 返回结构或帖子ID不匹配，拒绝展示错误帖子');
        throw new Error('getSemPosts 返回结构或帖子ID不匹配');
      }
      PostContext.rememberDetail(result);
    }
    return result;
  }

  static async fetchReplies(postId: string, lastId: string, size: number): Promise<Object> {
    let url = `https://bbs-api.miyoushe.com/post/api/getPostReplies?post_id=${encodeURIComponent(postId)}&size=${size}&only_good_replies=false&is_hot=true`;
    if (lastId !== '') { url += `&last_id=${encodeURIComponent(lastId)}`; }
    const raw = await MysHttp.request(url, PostApi.headers());
    if (raw.httpCode !== 200) { throw new Error(`HTTP ${raw.httpCode}`); }
    return JSON.parse(raw.body) as Object;
  }

  static async fetchSubReplies(postId: string, floorId: number, gid: number, lastId: string, size: number): Promise<Object> {
    const actualGid = PostContext.gameOf(postId) || gid;
    let url = `https://bbs-api.miyoushe.com/post/wapi/getSubReplies?post_id=${encodeURIComponent(postId)}&floor_id=${floorId}&gids=${actualGid}&size=${size}`;
    if (lastId !== '') { url += `&last_id=${encodeURIComponent(lastId)}`; }
    const raw = await MysHttp.request(url, PostApi.headers());
    if (raw.httpCode !== 200) { throw new Error(`HTTP ${raw.httpCode}`); }
    return JSON.parse(raw.body) as Object;
  }
}
