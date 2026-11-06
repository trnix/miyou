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

  // 只输出形态和白名单标识，禁止将会话、个人资料或正文字符串复制到结构日志。
  private static shapeNode(value: Object | undefined, path: string, key: string, depth: number, lines: string[]): void {
    if (lines.length >= 120) { return; }
    if (/cookie|token|authorization|password|secret|credential|device|fingerprint|email|phone|mobile|uid|nickname|introduce|avatar|^user$/i.test(key)) {
      lines.push(path + ' = [已省略]');
      return;
    }
    if (value === undefined) { lines.push(path + ' = undefined'); return; }
    if (value === null) { lines.push(path + ' = null'); return; }
    if (typeof value === 'string') {
      if (key === 'post_id' && /^\d+$/.test(value)) {
        lines.push(path + ' = string:' + value);
      } else {
        const trimmed = value.trim();
        const hint = trimmed.startsWith('[') ? ', starts=[' : (trimmed.startsWith('{') ? ', starts={' : '');
        lines.push(path + ` = string(length=${value.length}${hint})`);
      }
      return;
    }
    if (typeof value === 'number') {
      const show = key === 'retcode' || key === 'game_id' || key === 'gids' || key === 'post_id';
      lines.push(path + (show ? ' = number:' + value.toString() : ' = number'));
      return;
    }
    if (typeof value === 'boolean') { lines.push(path + ' = boolean'); return; }
    if (Array.isArray(value)) {
      const list = value as Object[];
      lines.push(path + ` = array(length=${list.length})`);
      if (depth >= 7) { lines.push(path + ' [达到深度上限]'); return; }
      for (let i = 0; i < Math.min(3, list.length) && lines.length < 120; i++) {
        PostApi.shapeNode(list[i], path + '[' + i + ']', '', depth + 1, lines);
      }
      if (list.length > 3 && lines.length < 120) { lines.push(path + ` [其余${list.length - 3}项未展开]`); }
      return;
    }
    if (typeof value === 'object') {
      const record = value as Record<string, Object>;
      const keys: string[] = Object.keys(record);
      const shown = keys.slice(0, 24);
      lines.push(path + ` = object(keys=${keys.length}): ` + shown.map((name: string) => name.substring(0, 48)).join(', '));
      if (depth >= 7) { lines.push(path + ' [达到深度上限]'); return; }
      for (let i = 0; i < shown.length && lines.length < 120; i++) {
        const name = shown[i];
        PostApi.shapeNode(record[name], path + '.' + name.substring(0, 48), name, depth + 1, lines);
      }
      if (keys.length > 24 && lines.length < 120) { lines.push(path + ` [其余${keys.length - 24}个键未展开]`); }
      return;
    }
    lines.push(path + ' = ' + typeof value);
  }

  private static structuralSummary(result: Record<string, Object>): string {
    const lines: string[] = [];
    PostApi.shapeNode(result['retcode'], 'retcode', 'retcode', 0, lines);
    PostApi.shapeNode(result['data'], 'data', 'data', 0, lines);
    if (lines.length >= 120) { lines.push('[字段树达到120行上限]'); }
    const report = lines.join('\n');
    return report.length > 12000 ? report.substring(0, 12000) + '\n[字数上限截断]' : report;
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
    if (resultCode === 0 && PostContext.matchesDetail(result, postId)) {
      PostContext.rememberDetail(result);
      return result;
    }
    if (resultCode === 0) {
      PostApi.trace(postId, `getSemPosts(gids=${gid}) HTTP 200 返回结构或帖子ID不匹配；expected_post_id=${postId}\n${PostApi.structuralSummary(result)}\n回落原版本提示，未放宽ID校验`);
    }
    return resultCode === 0 ? original : result;
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
