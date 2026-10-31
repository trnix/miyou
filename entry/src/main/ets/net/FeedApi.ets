import { MysHttp } from './MysHttp';
import { Endpoints } from './Endpoints';
import { Session } from '../auth/Session';

// 信息流接口（webHome）。请求头沿用 0.4.0 真机验证过的组合；登录后附带会话 Cookie。
export class FeedApi {
  static async fetchHome(gids: number, page: number, pageSize: number): Promise<Object> {
    const url = `${Endpoints.WEB_HOME}?gids=${gids}&page=${page}&page_size=${pageSize}`;
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
