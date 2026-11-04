import { MysHttp } from './MysHttp';
import { Session } from '../auth/Session';

// 帖子相关接口。请求头沿用 webHome 已验证组合；登录后附带会话 Cookie。
export class PostApi {
  private static headers(): Record<string, string> {
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      'Referer': 'https://www.miyoushe.com/',
      'Origin': 'https://www.miyoushe.com',
      'X-Requested-With': 'XMLHttpRequest',
      'Accept': 'application/json, text/plain, */*'
    };
    const cookie = Session.cookie();
    if (cookie.length > 0) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  // read=1：对齐上游实现（TeyvatGuide getPostFull 参数 { post_id, read: 1 }）；
  // 缺该参数时服务器将请求方视为旧版客户端，对新型帖子返回「请升级版本查看」。
  static async fetchPostFull(postId: string): Promise<Object> {
    const url = `https://bbs-api.miyoushe.com/post/wapi/getPostFull?post_id=${postId}&read=1`;
    const raw = await MysHttp.request(url, PostApi.headers());
    if (raw.httpCode !== 200) {
      throw new Error(`HTTP ${raw.httpCode}`);
    }
    return JSON.parse(raw.body) as Object;
  }

  // 热门评论；lastId 为分页游标（上一页末条 reply_id），首页传空串。
  static async fetchReplies(postId: string, lastId: string, size: number): Promise<Object> {
    let url = `https://bbs-api.miyoushe.com/post/api/getPostReplies?post_id=${postId}&size=${size}&only_good_replies=false&is_hot=true`;
    if (lastId !== '') {
      url += `&last_id=${lastId}`;
    }
    const raw = await MysHttp.request(url, PostApi.headers());
    if (raw.httpCode !== 200) {
      throw new Error(`HTTP ${raw.httpCode}`);
    }
    return JSON.parse(raw.body) as Object;
  }
}
