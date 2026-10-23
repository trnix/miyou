// 米游社只读数据模型；可选首页模块缺失时由页面隐藏。
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
  repost_num?: number;
  bookmark_num?: number;
  forward_num?: number;
}
export interface PostItem {
  post: Post;
  user: User;
  stat: Stat;
  statsLoaded?: boolean;
}
export interface HomeCarousel {
  cover: string;
  path: string;
}
export interface HomeTopic {
  id: number;
  name: string;
  cover: string;
  desc?: string;
}
export interface HomeTopics {
  list?: HomeTopic[];
  position?: number;
}
export interface SelectionPost {
  post_id: string;
  subject: string;
  forum_id?: number;
  forum_name?: string;
  banner?: string;
  view_type?: number;
}
export interface WebHomeData {
  recommended_posts?: PostItem[];
  carousels?: HomeCarousel[];
  recommended_topics?: HomeTopics;
  fixed_posts?: PostItem[];
  selection_post_list?: SelectionPost[];
}
export interface WebHomeResponse {
  retcode: number;
  message: string;
  data?: WebHomeData;
}
export interface DynamicPost {
  post_id: string;
  stat?: Stat;
}
export interface DynamicData {
  list?: DynamicPost[];
}
export interface DynamicResponse {
  retcode: number;
  message: string;
  data?: DynamicData;
}
export interface PostFullContainer {
  post: Post;
  user?: User;
  stat?: Stat;
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
