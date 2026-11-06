import { router } from '@kit.ArkUI';
import { FeedApi } from '../net/FeedApi';
import { FeedPost, HomeResult, FeedModels, formatCount } from '../model/FeedModels';
import { GlassTheme } from './GlassTheme';
import { GameInfo, gameByGids, defaultOrder, cleanOrder } from '../net/GameCatalog';

@Component
export struct HomeTab {
  scroller: Scroller = new Scroller();
  @StorageLink('homeChannelOrder') @Watch('onChannelsChanged') homeOrder: number[] = [];
  @StorageLink('glassLevel') glassLevel: number = 2;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State currentGid: number = 2;
  @State posts: FeedPost[] = [];
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State refreshing: boolean = false;
  @State noMore: boolean = false;
  @State errorText: string = '';
  @State firstLoaded: boolean = false;
  private readonly channelBar: number = 46;
  private readonly bottomPill: number = 64;
  private page: number = 1;
  private requestSeq: number = 0;
  private active: boolean = false;

  private vp(px: number): number { return this.getUIContext().px2vp(px); }
  private topOffset(): number { return this.channelBar; }
  private bottomOffset(): number { return this.vp(this.safeBottomPx) + this.bottomPill + 8; }
  private channelList(): GameInfo[] {
    const ids = this.homeOrder.length > 0 ? cleanOrder(this.homeOrder) : defaultOrder();
    return ids.map((id: number) => gameByGids(id));
  }

  onChannelsChanged(): void {
    if (!this.active) { return; }
    const ids = this.homeOrder.length > 0 ? cleanOrder(this.homeOrder) : defaultOrder();
    if (ids.indexOf(this.currentGid) < 0) { this.switchChannel(ids[0]); }
  }

  aboutToAppear(): void {
    this.active = true;
    this.onChannelsChanged();
    if (!this.firstLoaded && !this.loading) { this.reload(); }
  }

  aboutToDisappear(): void {
    this.active = false;
    this.requestSeq++;
    this.loading = false;
    this.loadingMore = false;
    this.refreshing = false;
  }

  private switchChannel(id: number): void {
    if (this.currentGid === id) { return; }
    this.currentGid = id;
    this.posts = [];
    this.firstLoaded = false;
    this.reload();
  }

  private async reload(): Promise<void> {
    const seq = ++this.requestSeq;
    const gid = this.currentGid;
    this.page = 1;
    this.loadingMore = false;
    this.noMore = false;
    this.errorText = '';
    this.refreshing = this.firstLoaded;
    this.loading = true;
    try {
      const raw = await FeedApi.fetchHome(gid, 1, 20);
      if (seq !== this.requestSeq) { return; }
      const result: HomeResult = FeedModels.parseHome(raw);
      if (result.retcode === 0) {
        this.posts = result.posts;
        this.firstLoaded = true;
        this.noMore = result.posts.length < 20;
      } else { this.errorText = `接口返回 ${result.retcode}（${result.message}）`; }
    } catch (e) {
      if (seq === this.requestSeq) { this.errorText = '网络异常，请检查网络后重试'; }
    } finally {
      if (seq === this.requestSeq) { this.loading = false; this.refreshing = false; }
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loading || this.loadingMore || this.noMore || !this.firstLoaded) { return; }
    const seq = this.requestSeq;
    const gid = this.currentGid;
    const next = this.page + 1;
    this.loadingMore = true;
    try {
      const raw = await FeedApi.fetchHome(gid, next, 20);
      if (seq !== this.requestSeq) { return; }
      const result: HomeResult = FeedModels.parseHome(raw);
      if (result.retcode === 0) {
        this.page = next;
        const merged = this.posts.slice();
        const seen = new Set<string>();
        merged.forEach((p: FeedPost) => seen.add(p.postId));
        result.posts.forEach((p: FeedPost) => {
          if (!seen.has(p.postId)) { seen.add(p.postId); merged.push(p); }
        });
        this.posts = merged;
        this.noMore = result.posts.length < 20;
      }
    } catch (e) {
      // 保留已有内容，允许重试。
    } finally { if (seq === this.requestSeq) { this.loadingMore = false; } }
  }

  @Builder
  MediaImage(url: string, showMore: boolean, moreCount: number) {
    Stack() {
      Image(url).width('100%').height(120).borderRadius(8)
        .objectFit(ImageFit.Cover).backgroundColor('#F2F4F7')
      if (showMore) {
        Column() { Text(`+${moreCount}`).fontSize(16).fontColor('#FFFFFF').fontWeight(FontWeight.Bold) }
          .width('100%').height(120).borderRadius(8).backgroundColor('#73000000')
          .justifyContent(FlexAlign.Center)
      }
    }.layoutWeight(1)
  }

  @Builder
  PostCard(post: FeedPost) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Image(post.avatar).width(40).height(40).borderRadius(20)
          .backgroundColor('#F2F4F7').alt($r('app.media.app_icon'))
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(post.author).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#101828')
            if (post.isOfficial) {
              Text('官').fontSize(10).fontColor('#1570EF').backgroundColor('#E5F6FF')
                .borderRadius(4).padding({ left: 4, right: 4, top: 1, bottom: 1 })
            }
            if (post.isTop) {
              Text('置顶').fontSize(10).fontColor('#E66900').backgroundColor('#FFF3E5')
                .borderRadius(4).padding({ left: 4, right: 4, top: 1, bottom: 1 })
            }
          }
          Text(post.timeText + (post.forumName !== '' ? ' · ' + post.forumName : ''))
            .fontSize(12).fontColor('#98A2B3')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%')
      if (post.title !== '') {
        Text(post.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#101828')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
      }
      if (post.excerpt !== '') {
        Text(post.excerpt).fontSize(14).fontColor('#667085').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').lineHeight(21)
      }
      if (post.images.length === 1) {
        Image(post.images[0]).width('100%').height(180).borderRadius(8)
          .objectFit(ImageFit.Cover).backgroundColor('#F2F4F7')
      } else if (post.images.length > 1) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            this.MediaImage(post.images[0], false, 0)
            this.MediaImage(post.images[1], false, 0)
          }
          if (post.images.length > 2) {
            Row({ space: 8 }) {
              this.MediaImage(post.images[2], false, 0)
              if (post.images.length > 3) {
                this.MediaImage(post.images[3], post.imageCount > 4, post.imageCount - 4)
              } else { Blank() }
            }
          }
        }.width('100%')
      }
      if (post.topics.length > 0) {
        Row({ space: 8 }) {
          ForEach(post.topics.slice(0, 3), (t: string) => {
            Text(t).fontSize(12).fontColor('#475467').backgroundColor('#F2F4F7')
              .borderRadius(10).padding({ left: 10, right: 10, top: 4, bottom: 4 })
          })
        }.width('100%')
      }
      Row({ space: 24 }) {
        Text(`浏览 ${formatCount(post.viewNum)}`).fontSize(13).fontColor('#98A2B3')
        Text(`评论 ${formatCount(post.replyNum)}`).fontSize(13).fontColor('#98A2B3')
        Text(`点赞 ${formatCount(post.likeNum)}`).fontSize(13).fontColor('#98A2B3')
        Blank()
        Text('只读').fontSize(11).fontColor('#C0C4CC')
      }.width('100%')
    }.alignItems(HorizontalAlign.Start).width('100%').padding(14)
      .backgroundColor('#FFFFFF').borderRadius(14)
      .onClick(() => router.pushUrl({ url: 'pages/PostDetail', params: { postId: post.postId } }))
  }

  @Builder
  FooterNote() {
    Row() {
      Text(this.loadingMore ? '加载更多…' : (this.noMore ? '已经到底啦' : '上拉加载更多'))
        .fontSize(12).fontColor('#98A2B3')
    }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 14, bottom: 6 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.errorText !== '' && this.posts.length === 0) {
        Column({ space: 12 }) {
          Text(this.errorText).fontSize(14).fontColor('#667085')
          Button('重试').onClick(() => this.reload())
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else if (!this.firstLoaded && this.loading) {
        Column() { Text('加载中…').fontSize(14).fontColor('#98A2B3') }
          .width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else if (this.posts.length === 0 && this.firstLoaded) {
        Column() { Text('暂无内容').fontSize(14).fontColor('#98A2B3') }
          .width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.refreshing }) {
          List({ space: 12, scroller: this.scroller }) {
            ForEach(this.posts, (post: FeedPost) => {
              ListItem() { this.PostCard(post) }
            }, (post: FeedPost) => post.postId)
            ListItem() { this.FooterNote() }
          }.width('100%').height('100%').padding({ left: 12, right: 12 })
            .contentStartOffset(this.topOffset()).contentEndOffset(this.bottomOffset())
            .scrollBar(BarState.Off).onReachEnd(() => this.loadMore())
        }.width('100%').height('100%').onRefreshing(() => this.reload())
      }
      Row({ space: 6 }) {
        Scroll() {
          Row({ space: 4 }) {
            ForEach(this.channelList(), (ch: GameInfo) => {
              Column({ space: 4 }) {
                Text(ch.short).fontSize(this.currentGid === ch.gids ? 17 : 15)
                  .fontWeight(this.currentGid === ch.gids ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.currentGid === ch.gids ? ch.color : '#667085').maxLines(1)
                Column().width(18).height(3).borderRadius(2)
                  .backgroundColor(this.currentGid === ch.gids ? ch.color : '#00000000')
              }.padding({ left: 10, right: 10, top: 8 }).flexShrink(0)
                .onClick(() => this.switchChannel(ch.gids))
            }, (ch: GameInfo) => ch.gids.toString())
          }.alignItems(VerticalAlign.Top)
        }.layoutWeight(1).height(this.channelBar).scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off).align(Alignment.Start)
        Button('频道', { type: ButtonType.Capsule }).fontSize(13).height(32).width(64)
          .backgroundColor('#1570EF').fontColor('#FFFFFF').margin({ right: 8 })
          .onClick(() => router.pushUrl({ url: 'pages/ChannelManage', params: { target: 'home' } }))
      }.width('100%').height(this.channelBar).padding({ left: 4 })
        .backgroundColor(GlassTheme.barColor(this.glassLevel))
        .systemMaterial(GlassTheme.material(this.glassLevel))
        .border({ width: { bottom: 0.5 }, color: GlassTheme.edgeColor(this.glassLevel) })
    }.width('100%').height('100%')
  }
}
