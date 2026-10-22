// 米游社接口数据模型(仅覆盖阶段1只读所需字段)

export interface PostImage {
  url: string;
  height: number;
  width: number;
}

export interface Post {
  post_id: string;
  subject: string;
  cover: string;
  images?: PostImage[];
  view_type?: number;
  created_at?: number;
  content?: string;
}

export interface User {
  uid: string;
  nickname: string;
  avatar_url: string;
}

export interface Stat {
  view_num: number;
  like_num: number;
  reply_num: number;
  repost_num: number;
}

export interface PostItem {
  post: Post;
  user: User;
  stat: Stat;
}

export interface WebHomeData {
  recommended_posts?: PostItem[];
}

export interface WebHomeResponse {
  retcode: number;
  message: string;
  data?: WebHomeData;
}

export interface PostFullContainer {
  post: Post;
  vod_list?: PostImage[];
}

export interface PostDetailData {
  post?: PostFullContainer;
  user?: User;
  stat?: Stat;
}

export interface PostDetailResponse {
  retcode: number;
  message: string;
  data?: PostDetailData;
}
