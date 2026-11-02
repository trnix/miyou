import { MysHttp, RawResult } from './MysHttp';
import { Session } from '../auth/Session';

// 消息中心接口。端点为推测候选（公开社区无文档），采用双通道策略：
// 先网页头组合请求，retcode 非 0 时自动换全 x-rpc 头重试；
// 两通道的原始结果都交还页面层进入诊断卡，便于真机一次校准。
export class NotifyApi {
  private static readonly BASE: string = 'https://bbs-api.miyoushe.com/apihub/sapi';

  private static webHeaders(): Record<string, string> {
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

  // 双通道请求：网页头优先，失败换 x-rpc 全头；返回最终通道的结果与诊断文本。
  private static async fetch(url: string): Promise<RawResult> {
    try {
      const a = await MysHttp.request(url, NotifyApi.webHeaders());
      if (a.httpCode === 200) {
        try {
          const obj = JSON.parse(a.body) as Record<string, Object>;
          const rc = obj['retcode'];
          if (typeof rc === 'number' && rc === 0) {
            return a;
          }
        } catch (e) {
          // 非 JSON，落到第二通道
        }
      }
    } catch (e) {
      // 网络异常，落到第二通道
    }
    return await MysHttp.request(url, MysHttp.buildHeaders(true));
  }

  static async fetchMessageCnt(): Promise<RawResult> {
    return NotifyApi.fetch(`${NotifyApi.BASE}/getMessageCnt`);
  }

  // type: 1=评论和@ 2=收到的赞 3=新增关注（候选编号，真机校准）
  static async fetchNotifyList(type: number, lastId: string, size: number): Promise<RawResult> {
    let url = `${NotifyApi.BASE}/getNotifyList?type=${type}&size=${size}`;
    if (lastId !== '') {
      url += `&last_id=${lastId}`;
    }
    return NotifyApi.fetch(url);
  }

  static trimBody(body: string): string {
    return body.length > 160 ? body.substring(0, 160) + '…' : body;
  }
}
