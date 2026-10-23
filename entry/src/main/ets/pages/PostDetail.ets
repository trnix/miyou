import { router } from '@kit.ArkUI';
import { MiyousheApi } from '../net/MiyousheApi';
import { Reply, ReplyItem, ReplyStructContent } from '../model/MiyousheModels';
import { Format } from '../utils/Format';

interface ReaderImage { url: string; width?: number; height?: number; }
interface ReaderPost {
  subject: string; content?: string; images?: string[]; created_at?: number; view_type?: number;
}
interface ReaderUser { nickname?: string; avatar_url?: string; }
interface ReaderStat { view_num?: number; like_num?: number; reply_num?: number; }
interface ReaderContainer {
  post?: ReaderPost; user?: ReaderUser; stat?: ReaderStat; image_list?: ReaderImage[]; vod_list?: ReaderImage[];
}
interface ReaderData { post?: ReaderContainer; user?: ReaderUser; stat?: ReaderStat; }
interface ReaderResponse { retcode: number; message: string; data?: ReaderData; }

@Entry
@Component
struct PostDetail {
  @State loading: boolean = true;
  @State error: string = '';
  @State title: string = '';
  @State author: string = '';
  @State avatar: string = '';
  @State body: string = '';
  @State images: ReaderImage[] = [];
  @State statsText: string = '';
  @State date: string = '';
  @State isVideo: boolean = false;
  @State preview: boolean = false;
  @State previewIndex: number = 0;
  @State replies: ReplyItem[] = [];
  @State repliesState: string = 'idle';
  private postId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined;
    this.postId = params && params.post_id ? params.post_id : '';
    this.load();
  }

  onBackPress(): boolean {
    if (this.preview) { this.preview = false; return true; }
    return false;
  }

  private count(value: number | undefined): string {
    return value !== undefined && Number.isFinite(value) && value >= 0 ? Format.num(value) : '—';
  }

  private async load(): Promise<void> {
    if (this.loading && this.title !== '') { return; }
    this.loading = true;
    this.error = '';
    try {
      if (!/^\d+$/.test(this.postId)) { throw new Error('缺少有效的帖子 ID'); }
      const result = await MiyousheApi.fetchPostFull(this.postId);
      // Dedicated transport model: images contains URL strings, image_list contains metadata.
      const response = JSON.parse(JSON.stringify(result)) as ReaderResponse;
      const data = response.data;
      if (response.retcode !== 0 || !data || !data.post || !data.post.post) {
        throw new Error(response.message || '帖子内容为空');
      }
      const container = data.post;
      const post = container.post;
      if (!post) { throw new Error('帖子内容为空'); }
      const user = container.user ? container.user : data.user;
      const stat = container.stat ? container.stat : data.stat;
      this.title = post.subject ? post.subject : '帖子详情';
      this.author = user && user.nickname ? user.nickname : '未知作者';
      this.avatar = user && user.avatar_url ? user.avatar_url : '';
      this.date = post.created_at ? Format.time(post.created_at) : '';
      this.body = post.content ? Format.stripHtml(post.content) : '';
      this.statsText = stat ? `${this.count(stat.view_num)} 浏览 · ${this.count(stat.like_num)} 赞 · ${this.count(stat.reply_num)} 评论` : '统计暂不可用';
      this.isVideo = post.view_type === 5 || (container.vod_list ? container.vod_list.length > 0 : false);
      const next: ReaderImage[] = [];
      const seen: Set<string> = new Set<string>();
      const metadata: ReaderImage[] = container.image_list ? container.image_list : [];
      metadata.forEach((image: ReaderImage) => {
        if (image.url && /^https:\/\//.test(image.url) && !seen.has(image.url)) {
          seen.add(image.url); next.push(image);
        }
      });
      if (next.length === 0) {
        const urls: string[] = post.images ? post.images : [];
        urls.forEach((url: string) => {
          if (typeof url === 'string' && /^https:\/\//.test(url) && !seen.has(url)) {
            seen.add(url); next.push({ url: url });
          }
        });
      }
      this.images = next;
      // 评论只读; 失败降级提示, 不影响正文阅读。
      this.loadReplies();
    } catch (e) {
      this.error = e instanceof Error ? e.message : '加载失败，请重试';
    } finally { this.loading = false; }
  }

  private async loadReplies(): Promise<void> {
    this.repliesState = 'loading';
    try {
      const response = await MiyousheApi.fetchPostReplies(this.postId);
      const data = response.data;
      if (response.retcode !== 0 || !data || !data.list) { throw new Error(response.message); }
      this.replies = data.list;
      this.repliesState = 'done';
    } catch (e) {
      this.replies = [];
      this.repliesState = 'failed';
    }
  }

  private replyText(reply: Reply): string {
    if (reply.struct_content && reply.struct_content.length > 0) {
      const parts: string[] = [];
      reply.struct_content.forEach((piece: ReplyStructContent) => {
        if (piece.insert) { parts.push(piece.insert); }
      });
      const text: string = parts.join('').replace(/\n{3,}/g, '\n\n').trim();
      if (text !== '') { return text; }
    }
    return reply.content ? Format.stripHtml(reply.content) : '';
  }

  private imageRatio(image: ReaderImage): number {
    return image.width && image.height && image.width > 0 && image.height > 0 ? image.width / image.height : 1;
  }

  @Builder
  Preview() {
    Column() {
      Row() {
        Text(`${this.previewIndex + 1} / ${this.images.length}`).fontColor(Color.White).fontSize(15).layoutWeight(1)
        Button('关闭').onClick(() => this.preview = false)
      }.width('100%').padding(16)
      Swiper() {
        ForEach(this.images, (image: ReaderImage) => {
          Image(image.url).width('100%').height('100%').objectFit(ImageFit.Contain)
        }, (image: ReaderImage) => image.url)
      }.width('100%').layoutWeight(1).index(this.previewIndex).loop(false).indicator(false)
        .onChange((index: number) => this.previewIndex = index)
      Text('左右滑动切换图片').fontSize(12).fontColor('#CCCCCC').padding(16)
    }.width('100%').height('100%').backgroundColor(Color.Black)
  }

  @Builder
  ReplyCard(item: ReplyItem) {
    Row({ space: 10 }) {
      if (item.user && item.user.avatar_url && /^https:\/\//.test(item.user.avatar_url)) {
        Image(item.user.avatar_url).width(30).height(30).borderRadius(15)
      }
      Column({ space: 4 }) {
        Row() {
          Text(item.user && item.user.nickname ? item.user.nickname : '米游社用户')
            .fontSize(13).fontColor('#175CD3').fontWeight(FontWeight.Medium).layoutWeight(1)
          Text(item.reply.created_at ? Format.time(item.reply.created_at) : '')
            .fontSize(11).fontColor('#98A2B3')
        }.width('100%')
        Text(this.replyText(item.reply)).fontSize(14).lineHeight(22).fontColor('#344054').width('100%')
        Row({ space: 12 }) {
          Text(item.reply.like_num !== undefined ? `${Format.num(item.reply.like_num)} 赞` : '')
            .fontSize(11).fontColor('#98A2B3')
          Text(item.reply.sub_replies_count && item.reply.sub_replies_count > 0 ?
            `${Format.num(item.reply.sub_replies_count)} 条回复` : '')
            .fontSize(11).fontColor('#98A2B3')
        }.width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(14).backgroundColor(Color.White).borderRadius(16).alignItems(VerticalAlign.Top)
  }

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#F7F8FA')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Row() {
          Button('返回').onClick(() => router.back())
          Text('帖子详情').fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
          Button('重载').enabled(!this.loading).onClick(() => this.load())
        }.width('100%').padding(12)
        if (this.loading) {
          Column() { LoadingProgress().width(42).height(42) }
            .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.error !== '') {
          Column({ space: 16 }) {
            Text(this.error).fontColor('#B42318').textAlign(TextAlign.Center)
            Button('重试').onClick(() => this.load())
          }.width('100%').layoutWeight(1).padding(24).justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 16 }) {
              Text(this.title).fontSize(23).fontWeight(FontWeight.Bold).width('100%')
              Row({ space: 8 }) {
                if (this.avatar && /^https:\/\//.test(this.avatar)) { Image(this.avatar).width(32).height(32).borderRadius(16) }
                Text(this.author).fontSize(14).fontColor('#475467').layoutWeight(1)
                Text(this.date).fontSize(12).fontColor('#98A2B3')
              }.width('100%')
              Text(this.statsText).fontSize(12).fontColor('#98A2B3').width('100%')
              if (this.isVideo) {
                Text('视频播放尚未接入，当前展示图文内容。').fontSize(13).fontColor('#B54708')
                  .width('100%').padding(12).backgroundColor('#FFFAEB').borderRadius(12)
              }
              if (this.body) {
                Text(this.body).fontSize(16).lineHeight(27).fontColor('#344054').width('100%')
                  .copyOption(CopyOptions.LocalDevice)
              }
              ForEach(this.images, (image: ReaderImage, index: number) => {
                Image(image.url).width('100%').aspectRatio(this.imageRatio(image)).objectFit(ImageFit.Contain)
                  .borderRadius(12).onClick(() => { this.previewIndex = index; this.preview = true; })
              }, (image: ReaderImage) => image.url)
              Text('图片可点击预览 · 正文可长按复制').fontSize(11).fontColor('#98A2B3')
              if (this.repliesState !== 'idle') {
                Row() {
                  Text('评论').fontSize(18).fontWeight(FontWeight.Bold)
                  Blank()
                  Text('热门优先 · 只读').fontSize(11).fontColor('#98A2B3')
                }.width('100%').margin({ top: 8 })
              }
              if (this.repliesState === 'loading') {
                LoadingProgress().width(28).height(28)
              } else if (this.repliesState === 'failed') {
                Column({ space: 12 }) {
                  Text('评论暂不可用，接口可能已变更。').fontSize(13).fontColor('#B54708')
                    .width('100%').textAlign(TextAlign.Center)
                  Button('重试评论').onClick(() => this.loadReplies())
                }.width('100%').padding(12)
              } else if (this.repliesState === 'done' && this.replies.length === 0) {
                Text('还没有评论，去官方客户端抢沙发吧。').fontSize(13).fontColor('#98A2B3').width('100%')
              } else if (this.repliesState === 'done') {
                Column({ space: 12 }) {
                  ForEach(this.replies, (item: ReplyItem) => {
                    this.ReplyCard(item)
                  }, (item: ReplyItem) => item.reply.reply_id)
                  Text('评论仅支持浏览，回复请前往米游社官方渠道。').fontSize(11).fontColor('#98A2B3')
                    .width('100%').textAlign(TextAlign.Center)
                }.width('100%')
              }
            }.width('100%').padding(16).alignItems(HorizontalAlign.Start)
          }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
        }
      }.width('100%').height('100%')
      if (this.preview) { this.Preview() }
    }.width('100%').height('100%')
  }
}
