// 网页只读接口；不携带登录凭据，统计失败不阻断帖子浏览。
import { http } from '@kit.NetworkKit';
import { WebHomeResponse, PostDetailResponse, PostItem, DynamicResponse, DynamicPost, Stat } from '../model/MiyousheModels';

const WEB_HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  'Referer': 'https://www.miyoushe.com/',
  'Origin': 'https://www.miyoushe.com',
  'X-Requested-With': 'XMLHttpRequest',
  'Accept': 'application/json, text/plain, */*'
};

export class MiyousheApi {
  static readonly GIDS_GENSHIN: number = 2;

  static async fetchHomePosts(gids: number, page: number, pageSize: number): Promise<WebHomeResponse> {
    const size: number = Math.max(1, Math.min(50, Math.floor(pageSize)));
    const currentPage: number = Math.max(1, Math.floor(page));
    const url = `https://bbs-api-static.miyoushe.com/apihub/wapi/webHome?gids=${gids}&page=${currentPage}&page_size=${size}`;
    const response = JSON.parse(await MiyousheApi.httpGet(url)) as WebHomeResponse;
    const data = response.data;
    if (response.retcode !== 0 || !data) {
      return response;
    }
    const recommended: PostItem[] = data.recommended_posts ? data.recommended_posts : [];
    const fixed: PostItem[] = data.fixed_posts ? data.fixed_posts : [];
    await MiyousheApi.enrichStats(gids, recommended.concat(fixed));
    return response;
  }

  // 每批最多 50 个 ID，按 ID 关联，不依赖接口返回顺序。
  private static async enrichStats(gids: number, posts: PostItem[]): Promise<void> {
    const ids: string[] = [];
    const seen: Set<string> = new Set<string>();
    posts.forEach((item: PostItem) => {
      item.statsLoaded = false;
      const id: string = String(item.post.post_id);
      if (/^\d+$/.test(id) && !seen.has(id)) {
        seen.add(id);
        ids.push(id);
      }
    });
    const stats: Map<string, Stat> = new Map<string, Stat>();
    for (let offset: number = 0; offset < ids.length; offset += 50) {
      const batch: string[] = ids.slice(offset, offset + 50);
      try {
        const url: string = `https://bbs-api.miyoushe.com/post/wapi/getDynamicData?gids=${gids}&post_ids=${batch.join(',')}`;
        const response = JSON.parse(await MiyousheApi.httpGet(url, 5000)) as DynamicResponse;
        const data = response.data;
        if (response.retcode !== 0 || !data || !data.list) {
          continue;
        }
        data.list.forEach((entry: DynamicPost) => {
          const value = entry.stat;
          if (value && Number.isFinite(value.view_num) && value.view_num >= 0 &&
            Number.isFinite(value.reply_num) && value.reply_num >= 0 &&
            Number.isFinite(value.like_num) && value.like_num >= 0) {
            stats.set(String(entry.post_id), value);
          }
        });
      } catch (e) {
        console.warn('Dynamic statistics unavailable; keeping homepage content.');
      }
    }
    posts.forEach((item: PostItem) => {
      const value = stats.get(String(item.post.post_id));
      if (value) {
        item.stat = value;
        item.statsLoaded = true;
      }
    });
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
