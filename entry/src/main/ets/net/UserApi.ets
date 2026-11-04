import { MysHttp, RawResult } from './MysHttp';
import { Session } from '../auth/Session';

// 用户主页相关接口。getUserFullInfo 与 userPost 均为匿名可用的 bbs 域读接口；
// 请求头沿用 webHome 已验证组合，登录后附带会话 Cookie（可见关注关系等字段）。
export class UserApi {
  private static headers(): Record<string, string> {
    const headers: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      'Referer': 'https://www.miyoushe.com/',
      'Accept': 'application/json, text/plain, */*'
    };
    const cookie = Session.cookie();
    if (cookie.length > 0) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  static async fetchUserFullInfo(uid: string, gids: string): Promise<RawResult> {
    const url = `https://bbs-api.miyoushe.com/user/api/getUserFullInfo?uid=${encodeURIComponent(uid)}&gids=${encodeURIComponent(gids)}`;
    return await MysHttp.request(url, UserApi.headers());
  }

  static async fetchUserPost(uid: string, gids: string, offset: string, size: number): Promise<RawResult> {
    let url = `https://bbs-api.miyoushe.com/post/wapi/userPost?uid=${encodeURIComponent(uid)}&gids=${encodeURIComponent(gids)}&size=${size}`;
    if (offset !== '') {
      url += `&offset=${encodeURIComponent(offset)}`;
    }
    return await MysHttp.request(url, UserApi.headers());
  }
}
