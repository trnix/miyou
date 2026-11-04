import { router } from '@kit.ArkUI';
import { UserApi } from '../net/UserApi';
import { UserModels, UserProfile, UserPostItem } from '../model/UserModels';
import { GlassTheme } from '../view/GlassTheme';
import { formatCount } from '../model/FeedModels';

interface RouteParams {
  uid?: string;
}

@Entry
@Component
struct UserProfilePage {
  @StorageLink('glassLevel') glassLevel: number = 3;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State profile: UserProfile | null = null;
  @State loading: boolean = true;
  @State errorText: string = '';
  @State posts: UserPostItem[] = [];
  @State postLoading: boolean = false;
  @State postLoaded: boolean = false;
  @State postError: string = '';
  @State nextOffset: string = '';
  @State isLast: boolean = true;
  @State gid: number = 2; // 频道 gids：默认原神 2
  private uid: string = '';
  private gameTabs: Array<[string, number]> = [['原神', 2], ['星穹铁道', 6], ['绝区零', 8]];

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  aboutToAppear(): void {
    const params = router.getParams() as RouteParams | undefined;
    this.uid = params && params.uid ? params.uid : '';
    if (this.uid === '') {
      this.loading = false;
      this.errorText = '缺少用户 ID';
      return;
    }
    this.loadProfile();
    this.loadPosts(false);
  }

  private async loadProfile(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      const raw = await UserApi.fetchUserFullInfo(this.uid, this.gid.toString());
      const p = UserModels.parseProfile(raw.body);
      if (p.retcode === 0) {
        this.profile = p;
      } else {
        this.errorText = `接口返回 ${p.retcode}（${p.message}）`;
      }
    } catch (e) {
      this.errorText = '网络异常，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  private async loadPosts(more: boolean): Promise<void> {
    if (this.postLoading) {
      return;
    }
    this.postLoading = true;
    if (!more) {
      this.postError = '';
      this.nextOffset = '';
      this.posts = [];
    }
    try {
      const raw = await UserApi.fetchUserPost(this.uid, this.gid.toString(), more ? this.nextOffset : '', 20);
      const r = UserModels.parsePosts(raw.body);
      if (r.retcode === 0) {
        this.nextOffset = r.nextOffset;
        this.isLast = r.isLast;
        if (more) {
          const merged = this.posts.slice();
          const seen = new Set<string>();
          merged.forEach((x: UserPostItem) => seen.add(x.postId));
          r.posts.forEach((x: UserPostItem) => {
            if (!seen.has(x.postId)) {
              seen.add(x.postId);
              merged.push(x);
            }
          });
          this.posts = merged;
        } else {
          this.posts = r.posts;
        }
        this.postLoaded = true;
        this.postError = '';
      } else {
        this.postError = `帖子接口返回 ${r.retcode}（${r.message}）`;
      }
    } catch (e) {
      this.postError = '帖子加载失败，请检查网络';
    } finally {
      this.postLoading = false;
    }
  }

  @Builder
  TopBar() {
    Row({ space: 12 }) {
      Text('←').fontSize(22).fontColor('#101828')
        .onClick(() => router.back())
      Text('用户主页')
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
  ProfileCard() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Image(this.profile!.avatar)
          .width(56)
          .height(56)
          .borderRadius(28)
          .backgroundColor('#F2F4F7')
          .alt($r('app.media.app_icon'))
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(this.profile!.nickname)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#101828')
            if (this.profile!.isOfficial) {
              Text('官')
                .fontSize(10)
                .fontColor('#1570EF')
                .backgroundColor('#E5F6FF')
                .borderRadius(4)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            }
          }
          Text(`UID ${this.profile!.uid}${this.profile!.ipRegion !== '' ? ' · ' + this.profile!.ipRegion : ''}`)
            .fontSize(11)
            .fontColor('#98A2B3')
          if (this.profile!.certLabel !== '') {
            Text(this.profile!.certLabel)
              .fontSize(11)
              .fontColor('#1570EF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      if (this.profile!.introduce !== '') {
        Text(this.profile!.introduce)
          .fontSize(13)
          .fontColor('#667085')
          .width('100%')
          .lineHeight(19)
      }
      Row({ space: 20 }) {
        Text(`帖子 ${formatCount(Number(this.profile!.postNum))}`).fontSize(12).fontColor('#667085')
        Text(`关注 ${formatCount(Number(this.profile!.followCnt))}`).fontSize(12).fontColor('#667085')
        Text(`粉丝 ${formatCount(Number(this.profile!.followedCnt))}`).fontSize(12).fontColor('#667085')
        Text(`获赞 ${formatCount(Number(this.profile!.likeNum))}`).fontSize(12).fontColor('#667085')
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  PostRow(item: UserPostItem) {
    Column({ space: 5 }) {
      Text(item.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#101828')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row() {
        Text(item.timeText).fontSize(11).fontColor('#98A2B3')
        Blank()
        Text(`${formatCount(item.viewNum)} 浏览 · ${formatCount(item.replyNum)} 评论 · ${formatCount(item.likeNum)} 赞`)
          .fontSize(11)
          .fontColor('#98A2B3')
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/PostDetail', params: { postId: item.postId } });
    })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F8FA')

      Column() {
        if (this.loading && this.profile === null) {
          Column() {
            Text('加载中…').fontSize(14).fontColor('#98A2B3')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.errorText !== '' && this.profile === null) {
          Column({ space: 12 }) {
            Text(this.errorText).fontSize(14).fontColor('#667085')
            Button('重试').onClick(() => this.loadProfile())
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.profile !== null) {
          Scroll() {
            Column({ space: 14 }) {
              this.ProfileCard()

              // 频道切换
              Row({ space: 8 }) {
                ForEach(this.gameTabs, (tab: [string, number]) => {
                  Text(tab[0])
                    .fontSize(13)
                    .fontColor(this.gid === tab[1] ? '#1570EF' : '#667085')
                    .fontWeight(this.gid === tab[1] ? FontWeight.Medium : FontWeight.Normal)
                    .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                    .backgroundColor(this.gid === tab[1] ? '#2B1570EF' : '#FFFFFF')
                    .borderRadius(16)
                    .onClick(() => {
                      if (this.gid !== tab[1]) {
                        this.gid = tab[1];
                        this.loadPosts(false);
                      }
                    })
                })
              }
              .width('100%')

              // 帖子列表
              Column({ space: 10 }) {
                Text('帖子')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#101828')
                  .width('100%')
                if (this.posts.length === 0 && this.postLoading) {
                  Text('加载中…').fontSize(13).fontColor('#98A2B3').width('100%')
                } else if (this.posts.length === 0 && this.postError !== '') {
                  Text(this.postError).fontSize(13).fontColor('#667085').width('100%')
                  Button('重试').onClick(() => this.loadPosts(false))
                } else if (this.posts.length === 0 && this.postLoaded) {
                  Text('该用户在此频道暂无帖子').fontSize(13).fontColor('#98A2B3').width('100%')
                } else {
                  ForEach(this.posts, (item: UserPostItem) => {
                    this.PostRow(item)
                  }, (item: UserPostItem) => item.postId)
                  if (!this.isLast) {
                    Button(this.postLoading ? '加载中…' : '加载更多')
                      .enabled(!this.postLoading)
                      .onClick(() => this.loadPosts(true))
                  }
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 20 + this.vp(this.safeBottomPx) })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
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
