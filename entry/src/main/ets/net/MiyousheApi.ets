// 网页只读接口；不携带登录凭据，统计失败不阻断帖子浏览。
import { http } from '@kit.NetworkKit';
import { WebHomeResponse, PostDetailResponse, DynamicPost, DynamicResponse } from '../model/MiyousheModels';

const WEB_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  'Referer': 'https://www.miyoushe.com/',
  'Origin': 'https://www.miyoushe.com',
  'X-Requested-With': 'XMLHttpRequest',
  'Accept': 'application/json, text/plain, */*'
};

export class MiyousheApi {
  static readonly GIDS_GENSHIN: number = 2;
  private static readonly DYNAMIC_BATCH_SIZE: number = 50;

  static async fetchHomePosts(gids: number, page: number, pageSize: number): Promise<WebHomeResponse> {
    const size: number = Math.max(1, Math.min(50, Math.floor(pageSize)));
    const currentPage: number = Math.max(1, Math.floor(page));
    const url = `https://bbs-api-static.miyoushe.com/apihub/wapi/webHome?gids=${gids}&page=${currentPage}&page_size=${size}`;
    return JSON.parse(await MiyousheApi.httpGet(url)) as WebHomeResponse;
  }

  // 返回按 post_id 关联后的动态统计；失败的批次会跳过，不丢弃可用批次。
  static async fetchDynamicStats(gids: number, postIds: string[]): Promise<DynamicPost[]> {
    const unique: Set<string> = new Set<string>();
    postIds.forEach((raw: string) => {
      const id: string = String(raw);
      if (/^\d+$/.test(id)) {
        unique.add(id);
      }
    });
    const ids: string[] = Array.from(unique);
    const result: DynamicPost[] = [];
    for (let offset: number = 0; offset < ids.length; offset += MiyousheApi.DYNAMIC_BATCH_SIZE) {
      const batch: string[] = ids.slice(offset, offset + MiyousheApi.DYNAMIC_BATCH_SIZE);
      try {
        const url: string = `https://bbs-api.miyoushe.com/post/wapi/getDynamicData?gids=${gids}&post_ids=${batch.join(',')}`;
        const response = JSON.parse(await MiyousheApi.httpGet(url, 5000)) as DynamicResponse;
        const data = response.data;
        if (response.retcode === 0 && data && data.list) {
          result.push(...data.list);
        }
      } catch (e) {
        console.warn('Dynamic statistics unavailable for one batch.');
      }
    }
    return result;
  }

  static async fetchPostFull(postId: string): Promise<PostDetailResponse> {
    if (!/^\d+$/.test(postId)) {
      throw new Error('帖子 ID 格式不正确');
    }
    const url = `https://bbs-api.miyoushe.com/post/wapi/getPostFull?post_id=${encodeURIComponent(postId)}`;
    return JSON.parse(await MiyousheApi.httpGet(url)) as PostDetailResponse;
  }

  private static async httpGet(url: string, timeout: number = 15000): Promise<string> {
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: WEB_HEADERS,
        connectTimeout: timeout,
        readTimeout: timeout,
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
