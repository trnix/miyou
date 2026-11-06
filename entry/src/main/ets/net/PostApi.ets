import { MysHttp } from './MysHttp';
import { Session } from '../auth/Session';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { DsSign } from './DsSign';
import { PostContext } from './PostContext';

export interface PostProbe { url: string; httpCode: number; bodyExcerpt: string; }

// getSemPosts 返回结构包装：和 PostModels 期望的 data.post 形状相符
interface DetailArticleWrap { post: Record<string, Object>; }
interface DetailWrap { retcode: number; message: string; data: DetailArticleWrap; }

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

  // 网页客户端身份头组：与浏览器 F12 实捕一致的 x-rpc 四元组 + 可选 DS 签名。
  private static async webHeaders(query: string, ds: string): Promise<Record<string, string>> {
    await DeviceIdentity.ensureFp();
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36',
      'Referer': 'https://www.miyoushe.com/', 'Origin': 'https://www.miyoushe.com',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'x-rpc-app_version': '2.102.0', 'x-rpc-client_type': '4',
      'x-rpc-device_id': DeviceIdentity.deviceId(), 'x-rpc-device_fp': DeviceIdentity.deviceFp()
    };
    if (ds === 'ds1') {
      headers['Ds'] = DsSign.webDs1();
    } else if (ds === 'ds2') {
      headers['Ds'] = DsSign.webDs2(query);
    }
    const cookie = Session.cookie();
    if (cookie.length > 0) { headers['Cookie'] = cookie; }
    return headers;
  }

  // 追加式 trace：同一帖子的中间证据全部保留（截断保护 400 字符），不再被最后一跳覆盖。
  private static trace(id: string, text: string): void {
    const prev = PostApi.traces.get(id);
    let next = prev === undefined ? text : `${prev} | ${text}`;
    if (next.length > 400) {
      next = next.substring(next.length - 400);
    }
    PostApi.traces.delete(id);
    PostApi.traces.set(id, next);
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

  // 只允许本次排查或使用过的官方读取接口，防止任意域请求携带当前会话。
  static async probeUrl(url: string): Promise<PostProbe> {
    const ok = /^https:\/\/bbs-api\.miyoushe\.com\/(post\/wapi\/getPostFull|post\/api\/getPostFull|painter\/wapi\/getSemPosts)\?[^ \t]+$/.test(url) &&
      /([?&]post_id=\d+)(?:&|$)/.test(url);
    if (!ok) {
      return { url: '(不允许的诊断地址)', httpCode: 0, bodyExcerpt: '诊断地址必须在官方白名单内' };
    }
    return PostApi.doProbe(url);
  }

  // 头组变体对照诊断：同一条 getPostFull 按四种身份逐组试，找出最小解锁组合。
  static async probeVariants(postId: string): Promise<string> {
    const id = encodeURIComponent(postId);
    const gid = PostContext.gameOf(postId);
    const query = gid > 0 ? `gids=${gid}&post_id=${id}&read=1` : `post_id=${id}&read=1`;
    const url = `https://bbs-api.miyoushe.com/post/wapi/getPostFull?${query}`;
    const lines: string[] = [];
    lines.push(`postId: ${postId}`);
    lines.push(`gids: ${gid > 0 ? String(gid) : '(未知，未携带)'}`);
    lines.push(`device_id: ${DeviceIdentity.deviceId().length > 0 ? '已就位' : '(缺失)'}`);
    lines.push(`device_fp: ${DeviceIdentity.deviceFp().length > 0 ? '已就位' : '(缺失)'}`);
    lines.push(`cookie: ${Session.cookie().length > 0 ? '已登录' : '(未登录)'}`);
    lines.push('');
    const modes: string[] = ['baseline', 'rpc', 'ds1', 'ds2'];
    const labels: string[] = [
      'A 基线（b146 现头组，无 x-rpc/DS）',
      'B x-rpc 头族（无 DS）',
      'C x-rpc + DS1/LK2（完整网页身份）',
      'D x-rpc + DS2/x6（对照）'
    ];
    for (let i = 0; i < modes.length; i++) {
      let headers: Record<string, string>;
      if (modes[i] === 'baseline') {
        headers = PostApi.headers();
      } else {
        const ds = modes[i] === 'rpc' ? 'none' : modes[i];
        headers = await PostApi.webHeaders(query, ds);
      }
      lines.push(`—— ${labels[i]}`);
      try {
        const raw = await MysHttp.request(url, headers);
        let summary = `HTTP ${raw.httpCode}`;
        try {
          const obj = JSON.parse(raw.body) as Record<string, Object>;
          const rc = obj['retcode'];
          const msgVal = obj['message'];
          const msg = typeof msgVal === 'string' ? msgVal : '';
          const data = obj['data'];
          const hasData = data !== null && data !== undefined;
          summary += ` retcode=${typeof rc === 'number' ? rc : '?'} message=${msg} data=${hasData ? '有' : 'null'}`;
        } catch (e) {
          summary += ' ' + raw.body.substring(0, 120);
        }
        lines.push(summary);
      } catch (e) {
        lines.push('(请求异常)');
      }
      lines.push('');
    }
    return lines.join('\n');
  }

  static async fetchPostFull(postId: string): Promise<Object> {
    const id = encodeURIComponent(postId);
    PostApi.trace(postId, 'getPostFull 请求中');
    // F12 实捕的解锁组合：getPostFull?gids=8&post_id=…&read=1 + 网页客户端身份（x-rpc 四元组 + DS1）
    const gid = PostContext.gameOf(postId);
    const query = gid > 0 ? `gids=${gid}&post_id=${id}&read=1` : `post_id=${id}&read=1`;
    const raw = await MysHttp.request(`https://bbs-api.miyoushe.com/post/wapi/getPostFull?${query}`, await PostApi.webHeaders(query, 'ds1'));
    PostApi.trace(postId, `getPostFull HTTP ${raw.httpCode}`);
    if (raw.httpCode !== 200) { throw new Error(`HTTP ${raw.httpCode}`); }
    const original = JSON.parse(raw.body) as Record<string, Object>;
    const rc = original['retcode'];
    const value = original['message'];
    const msg = typeof value === 'string' ? value : '';
    PostApi.trace(postId, `getPostFull retcode=${typeof rc === 'number' ? rc : '缺失'}${gid > 0 ? ` (gids=${gid})` : ''}`);
    if (rc === 0) {
      if (!PostContext.matchesDetail(original, postId)) { throw new Error('详情返回的帖子ID不匹配'); }
      PostContext.rememberDetail(original);
      return original;
    }
    // 仅回退本次观测到的明确业务错误，不对403、鉴权失败或其它错误盲目重试。
    if (rc !== -1 || msg.indexOf('升级') < 0 || (original['data'] !== null && original['data'] !== undefined)) {
      return original;
    }
    if (gid <= 0) {
      PostApi.trace(postId, 'getPostFull retcode=-1；没有该帖的真实game_id，未猜测频道或扫描接口');
      return original;
    }
    const url = `https://bbs-api.miyoushe.com/painter/wapi/getSemPosts?gids=${gid}&post_id=${id}`;
    PostApi.trace(postId, `getSemPosts(gids=${gid}) 请求中`);
    const fallback = await MysHttp.request(url, PostApi.headers());
    PostApi.trace(postId, `getSemPosts(gids=${gid}) HTTP ${fallback.httpCode}`);
    if (fallback.httpCode !== 200) { throw new Error(`getSemPosts HTTP ${fallback.httpCode}`); }
    const result = JSON.parse(fallback.body) as Record<string, Object>;
    const resultCode = result['retcode'];
    PostApi.trace(postId, `getSemPosts(gids=${gid}) retcode=${typeof resultCode === 'number' ? resultCode : '缺失'}`);
    if (resultCode !== 0) { return result; }
    if (PostContext.matchesDetail(result, postId)) {
      PostContext.rememberDetail(result);
      return result;
    }
    const entry = PostContext.findDetailInList(result, postId);
    if (entry !== undefined) {
      const wrap: DetailWrap = { retcode: 0, message: 'OK', data: { post: entry } };
      PostContext.rememberDetail(wrap as Object);
      PostApi.trace(postId, `getSemPosts(gids=${gid}) list语义精准命中目标后包装为详情`);
      return wrap;
    }
    PostApi.trace(postId, `getSemPosts(gids=${gid}) 语义列表 ${PostContext.listIds(result)} 无目标，fallback 停用`);
    return original;
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
