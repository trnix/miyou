// 米游社网页版匿名接口(阶段1:只读浏览,无需登录)
// 接口于 2026-10-22 实测验证可用;若米哈游调整接口需抓包更新

import { http } from '@kit.NetworkKit';
import { WebHomeResponse, PostDetailResponse } from '../model/MiyousheModels';

// 模拟米游社网页环境的请求头(实测仅需这些,无需 Cookie/DS)
const WEB_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  'Referer': 'https://www.miyoushe.com/',
  'Origin': 'https://www.miyoushe.com',
  'X-Requested-With': 'XMLHttpRequest',
  'Accept': 'application/json, text/plain, */*'
};

export class MiyousheApi {
  static readonly GIDS_GENSHIN: number = 2;

  // 原神版块首页推荐帖子流
  static async fetchHomePosts(gids: number, page: number, pageSize: number): Promise<WebHomeResponse> {
    const url = `https://bbs-api-static.miyoushe.com/apihub/wapi/webHome?gids=${gids}&page=${page}&page_size=${pageSize}`;
    return JSON.parse(await MiyousheApi.httpGet(url)) as WebHomeResponse;
  }

  // 帖子详情
  static async fetchPostFull(postId: string): Promise<PostDetailResponse> {
    const url = `https://bbs-api.miyoushe.com/post/wapi/getPostFull?post_id=${postId}`;
    return JSON.parse(await MiyousheApi.httpGet(url)) as PostDetailResponse;
  }

  private static async httpGet(url: string): Promise<string> {
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: WEB_HEADERS,
        connectTimeout: 15000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });
      if (resp.responseCode !== 200) {
        throw new Error(`HTTP ${resp.responseCode}`);
      }
      return resp.result as string;
    } finally {
      req.destroy();
    }
  }
}
