// 用户主页模型与防御性解析。数据结构参照 UIGF hoyolab/user/info.md 与 TeyvatGuide Post.d.ts 的 UserPostRes。

export interface UserProfile {
  uid: string;
  nickname: string;
  introduce: string;
  avatar: string;
  ipRegion: string;
  certLabel: string;
  isOfficial: boolean;
  postNum: string;
  followCnt: string;
  followedCnt: string;
  likeNum: string;
  retcode: number;
  message: string;
}

export interface UserPostItem {
  postId: string;
  title: string;
  excerpt: string;
  timeText: string;
  viewNum: number;
  replyNum: number;
  likeNum: number;
}

export interface UserPostPage {
  retcode: number;
  message: string;
  posts: UserPostItem[];
  nextOffset: string;
  isLast: boolean;
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

function relTime(ts: number): string {
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

export class UserModels {
  static parseProfile(body: string): UserProfile {
    const result: UserProfile = {
      uid: '', nickname: '', introduce: '', avatar: '', ipRegion: '',
      certLabel: '', isOfficial: false,
      postNum: '0', followCnt: '0', followedCnt: '0', likeNum: '0',
      retcode: -1, message: ''
    };
    try {
      const obj = JSON.parse(body) as Record<string, Object>;
      const rc = obj['retcode'];
      result.retcode = typeof rc === 'number' ? rc : -1;
      result.message = asStr(obj['message']);
      const data = obj['data'] as Record<string, Object> | undefined;
      if (!data) {
        return result;
      }
      const u = data['user_info'] as Record<string, Object> | undefined;
      if (!u) {
        return result;
      }
      result.uid = asStr(u['uid']);
      result.nickname = asStr(u['nickname']);
      result.introduce = asStr(u['introduce']);
      result.avatar = asStr(u['avatar_url']);
      result.ipRegion = asStr(u['ip_region']);
      const cert = u['certification'] as Record<string, Object> | undefined;
      result.isOfficial = cert ? asNum(cert['type']) === 1 : false;
      result.certLabel = cert ? asStr(cert['label']) : '';
      const ache = u['achieve'] as Record<string, Object> | undefined;
      if (ache) {
        result.postNum = asStr(ache['post_num']);
        result.followCnt = asStr(ache['follow_cnt']);
        result.followedCnt = asStr(ache['followed_cnt']);
        result.likeNum = asStr(ache['like_num']);
      }
    } catch (e) {
      // 保留默认
    }
    return result;
  }

  static parsePosts(body: string): UserPostPage {
    const result: UserPostPage = { retcode: -1, message: '', posts: [], nextOffset: '', isLast: true };
    try {
      const obj = JSON.parse(body) as Record<string, Object>;
      const rc = obj['retcode'];
      result.retcode = typeof rc === 'number' ? rc : -1;
      result.message = asStr(obj['message']);
      const data = obj['data'] as Record<string, Object> | undefined;
      if (!data) {
        return result;
      }
      result.nextOffset = asStr(data['next_offset']);
      const il = data['is_last'];
      result.isLast = typeof il === 'boolean' ? il : true;
      const list = data['list'];
      if (Array.isArray(list)) {
        (list as Object[]).forEach((item: Object) => {
          const it = item as Record<string, Object>;
          const post = it['post'] as Record<string, Object> | undefined;
          const stat = it['stat'] as Record<string, Object> | undefined;
          const pid = post ? asStr(post['post_id']) : '';
          if (pid === '') {
            return;
          }
          result.posts.push({
            postId: pid,
            title: post ? asStr(post['subject']) : '',
            excerpt: post ? asStr(post['content']).replace(/<[^>]*>/g, '').substring(0, 120) : '',
            timeText: relTime(post ? asNum(post['created_at']) : 0),
            viewNum: stat ? asNum(stat['view_num']) : 0,
            replyNum: stat ? asNum(stat['reply_num']) : 0,
            likeNum: stat ? asNum(stat['like_num']) : 0
          });
        });
      }
    } catch (e) {
      // 保留已解析部分
    }
    return result;
  }
}
