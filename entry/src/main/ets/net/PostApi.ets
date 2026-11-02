import { MysHttp } from './MysHttp';
import { Session } from '../auth/Session';

// 帖子详情接口（getPostFull）。请求头沿用 webHome 已验证组合。
export class PostApi {
  static async fetchPostFull(postId: string): Promise<Object> {
    const url = `https://bbs-api.miyoushe.com/post/wapi/getPostFull?post_id=${postId}`;
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
    const raw = await MysHttp.request(url, headers);
    if (raw.httpCode !== 200) {
      throw new Error(`HTTP ${raw.httpCode}`);
    }
    return JSON.parse(raw.body) as Object;
  }
}
