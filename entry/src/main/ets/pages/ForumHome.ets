import { router } from '@kit.ArkUI';
import { FeedApi } from '../net/FeedApi';
import { FeedModels, FeedItem, FeedPost, WebHomeNavigator } from '../model/FeedModels';
import { PostModels, PostDetail } from '../model/PostModels';
import { GlassTheme } from '../view/GlassTheme';
import { formatCount } from '../model/FeedModels';

interface RouteParams {
  gid?: string;
}

// 从 FeedApi.fetchWebHome 拿子版块导航（已验证），点击切换后再按该子版块 gid 拉取信息流。
// R7a 骨架：单垂直列表 + 顶部横向导航（点击切换）；左右滑/最新排序待 R7b。
@Entry
@Component
struct ForumHomePage {
  @StorageLink('glassLevel') glassLevel: number = 3;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State navigators: WebHomeNavigator[] = [];
  @State selectedGid: number = 0;
  @State selectedLabel: string = '';
  @State posts: FeedPost[] = [];
  @State loadingNav: boolean = true;
  @State loadingPosts: boolean = false;
  @State errorText: string = '';
  private gid: number = 2;

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  aboutToAppear(): void {
    const params = router.getParams() as RouteParams | undefined;
    if (params && params.gid) {
      const n = Number(params.gid);
      if (!isNaN(n) && n > 0) {
        this.gid = n;
      }
    }
    this.loadNav();
  }

  private async loadNav(): Promise<void> {
    this.loadingNav = true;
    this.errorText = '';
    try {
      const navRes = await FeedApi.fetchWebHome(this.gid);
      this.navigators = navRes.navigators;
      if (navRes.navigators.length > 0) {
        this.selectedGid = navRes.navigators[0]!.gid;
        this.selectedLabel = navRes.navigators[0]!.label;
        this.loadPosts();
      } else {
        this.errorText = '该版块暂无导航';
      }
    } catch (e) {
      this.errorText = '导航加载失败，请检查网络';
    } finally {
      this.loadingNav = false;
    }
  }

  private async loadPosts(): Promise<void> {
    if (this.selectedGid <= 0) {
      return;
    }
    this.loadingPosts = true;
    try {
      // 用 FeedApi 的 getForumPostList 按 gid 拉该版块信息流（该接口 gid 即为子版块 id）
      const raw = await FeedApi.fetchFeed(this.selectedGid, '', 20);
      const r = FeedModels.parseFeed(raw);
      this.posts = r.posts;
    } catch (e) {
      this.errorText = '版块信息流加载失败，请检查网络';
    } finally {
      this.loadingPosts = false;
    }
  }

  private openPost(p: FeedPost): void {
    if (p.postId !== '') {
      router.pushUrl({ url: 'pages/PostDetail', params: { postId: p.postId } });
    }
  }

  @Builder
  TopBar() {
    Row({ space: 12 }) {
      Text('←').fontSize(22).fontColor('#101828')
        .onClick(() => router.back())
      Text('版块')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('').width(22)
    }
    .width('100%')
    .height(56 + this.vp(this.safeTopPx))
    .padding({ top: this.vp(this.safeTopPx), left: 16, right: 16 })
    .backgroundColor(GlassTheme.barColor(this.glassLevel))
    .systemMaterial(GlassTheme.material(this.glassLevel))
    .border({ width: { bottom: 0.5 }, color: GlassTheme.edgeColor(this.glassLevel) })
  }

  @Builder
  NavStrip() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.navigators, (nav: WebHomeNavigator) => {
          Text(nav.label)
            .fontSize(14)
            .fontColor(this.selectedGid === nav.gid ? '#1570EF' : '#475467')
            .fontWeight(this.selectedGid === nav.gid ? FontWeight.Medium : FontWeight.Normal)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(12)
            .backgroundColor(this.selectedGid === nav.gid ? '#E5F6FF' : 'transparent')
            .onClick(() => {
              if (this.selectedGid !== nav.gid) {
                this.selectedGid = nav.gid;
                this.selectedLabel = nav.label;
                this.loadPosts();
              }
            })
        })
      }
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .width('100%')
  }

  @Builder
  PostCard(item: FeedPost) {
    Column({ space: 8 }) {
      if (item.cover !== '') {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image(item.cover)
            .width('100%')
            .borderRadius(12)
            .objectFit(ImageFit.Cover)
            .constraintSize({ maxHeight: 360 })
          Text(item.title !== '' ? item.title : '')
            .fontSize(15)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
            .padding({ left: 12, right: 12, bottom: 12 })
            .backgroundBlendMode(BlendMode.NONE)
            .systemMaterial(BlurStyleMaterial.dark)
            .borderRadius(12)
            .width('100%')
        }
        .borderRadius(12)
      } else {
        Text(item.title)
          .fontSize(15)
          .fontColor('#101828')
          .fontWeight(FontWeight.Medium)
          .width('100%')
      }

      Row({ space: 12 }) {
        Text(item.createdAt)
          .fontSize(12)
          .fontColor('#98A2B3')
        Blank()
        Text(`浏览 ${formatCount(item.viewNum)}`)
          .fontSize(12)
          .fontColor('#98A2B3')
        Text(`评 ${formatCount(item.replyNum)}`)
          .fontSize(12)
          .fontColor('#98A2B3')
        Text(`赞 ${formatCount(item.likeNum)}`)
          .fontSize(12)
          .fontColor('#98A2B3')
      }
      .width('100%')
    }
    .padding(12)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(() => this.openPost(item))
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F7F8FA')

      Column() {
        if (this.loadingNav) {
          Column() {
            Text('加载中…').fontSize(14).fontColor('#98A2B3')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.errorText !== '') {
          Column({ space: 12 }) {
            Text(this.errorText).fontSize(14).fontColor('#667085')
            Button('重试').onClick(() => this.loadNav())
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          this.NavStrip()
          Scroll() {
            Column({ space: 12 }) {
              if (this.loadingPosts) {
                Text('加载中…')
                  .fontSize(13)
                  .fontColor('#98A2B3')
                  .padding(20)
              } else if (this.posts.length === 0) {
                Text('暂无帖子')
                  .fontSize(13)
                  .fontColor('#98A2B3')
                  .padding(20)
              } else {
                ForEach(this.posts, (p: FeedPost) => {
                  this.PostCard(p)
                }, (p: FeedPost) => p.postId)
              }
            }
            .padding({ left: 16, right: 16, top: 12, bottom: 20 + this.vp(this.safeBottomPx) })
            .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: 56 + this.vp(this.safeTopPx) })

      this.TopBar()
    }
    .width('100%')
    .height('100%')
  }
}
