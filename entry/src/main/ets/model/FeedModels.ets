// webHome 信息流模型与防御性解析：fixed（置顶）+ recommended 合并去重，字段缺失不崩。

export interface FeedPost {
  postId: string;
  title: string;
  excerpt: string;
  author: string;
  avatar: string;
  timeText: string;
  forumName: string;
  isOfficial: boolean;
  isTop: boolean;
  images: string[];
  imageCount: number;
  topics: string[];
  viewNum: number;
  replyNum: number;
  likeNum: number;
}

export interface HomeResult {
  retcode: number;
  message: string;
  posts: FeedPost[];
}

function asStr(v: Object | undefined): string {
  if (typeof v === 'string') {
    return v;
  }
  return '';
}

function asNum(v: Object | undefined): number {
  if (typeof v === 'number') {
    return v;
  }
  return 0;
}

function asBool(v: Object | undefined): boolean {
  if (typeof v === 'boolean') {
    return v;
  }
  return false;
}

export function formatCount(n: number): string {
  if (n >= 10000) {
    const s = (n / 10000).toFixed(1);
    if (s.endsWith('.0')) {
      return s.substring(0, s.length - 2) + '万';
    }
    return s + '万';
  }
  return n.toString();
}

function timeText(ts: number): string {
  if (ts <= 0) {
    return '';
  }
  const diff = Date.now() / 1000 - ts;
  if (diff < 3600) {
    const m = Math.max(1, Math.floor(diff / 60));
    return m + '分钟前';
  }
  if (diff < 86400) {
    return Math.floor(diff / 3600) + '小时前';
  }
  const d = new Date(ts * 1000);
  const mm = (d.getMonth() + 1).toString().padStart(2, '0');
  const dd = d.getDate().toString().padStart(2, '0');
  return `${mm}-${dd}`;
}

export class FeedModels {
  static parseHome(raw: Object): HomeResult {
    const obj = raw as Record<string, Object>;
    const rc = obj['retcode'];
    const retcode = typeof rc === 'number' ? rc : -1;
    const message = asStr(obj['message']);
    const posts: FeedPost[] = [];
    try {
      const data = obj['data'] as Record<string, Object> | undefined;
      const seen = new Set<string>();
      const fixed = data ? data['fixed_posts'] : undefined;
      if (Array.isArray(fixed)) {
        (fixed as Object[]).forEach((item: Object) => {
          const p = FeedModels.parseItem(item as Record<string, Object>, true);
          if (p.postId !== '' && !seen.has(p.postId)) {
            seen.add(p.postId);
            posts.push(p);
          }
        });
      }
      const rec = data ? data['recommended_posts'] : undefined;
      if (Array.isArray(rec)) {
        (rec as Object[]).forEach((item: Object) => {
          const p = FeedModels.parseItem(item as Record<string, Object>, false);
          if (p.postId !== '' && !seen.has(p.postId)) {
            seen.add(p.postId);
            posts.push(p);
          }
        });
      }
    } catch (e) {
      // 单项解析失败不丢弃整页
    }
    return { retcode, message, posts };
  }

  private static parseItem(it: Record<string, Object>, forceTop: boolean): FeedPost {
    const post = it['post'] as Record<string, Object> | undefined;
    const user = it['user'] as Record<string, Object> | undefined;
    const stat = it['stat'] as Record<string, Object> | undefined;
    const forum = it['forum'] as Record<string, Object> | undefined;

    const images: string[] = [];
    let imageCount = 0;
    if (post) {
      const imgs = post['images'];
      if (Array.isArray(imgs)) {
        (imgs as Object[]).forEach((iv: Object) => {
          const o = iv as Record<string, Object>;
          const u = asStr(o['url']);
          if (u !== '') {
            images.push(u);
          }
        });
      }
      imageCount = images.length;
      const cover = asStr(post['cover']);
      if (images.length === 0 && cover !== '') {
        images.push(cover);
        imageCount = 1;
      }
    }

    const topics: string[] = [];
    const topicsArr = it['topics'];
    if (Array.isArray(topicsArr)) {
      (topicsArr as Object[]).forEach((tv: Object) => {
        const o = tv as Record<string, Object>;
        const n = asStr(o['name']);
        if (n !== '') {
          topics.push(n);
        }
      });
    }

    const status = post ? post['post_status'] as Record<string, Object> | undefined : undefined;
    const isTop = forceTop || (status ? asBool(status['is_top']) : false);

    return {
      postId: post ? asStr(post['post_id']) : '',
      title: post ? asStr(post['subject']) : '',
      excerpt: post ? asStr(post['content']) : '',
      author: user ? asStr(user['nickname']) : '',
      avatar: user ? asStr(user['avatar_url']) : '',
      timeText: timeText(post ? asNum(post['created_at']) : 0),
      forumName: forum ? asStr(forum['name']) : '',
      isOfficial: status ? asBool(status['is_official']) : false,
      isTop: isTop,
      images: images,
      imageCount: imageCount,
      topics: topics,
      viewNum: stat ? asNum(stat['view_num']) : 0,
      replyNum: stat ? asNum(stat['reply_num']) : 0,
      likeNum: stat ? asNum(stat['like_num']) : 0
    };
  }
}
