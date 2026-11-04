import { router } from '@kit.ArkUI';
import { FeedApi } from '../net/FeedApi';
import { FeedModels, FeedItem, FeedPost, FeedUser, WebHomeNavigator } from '../model/FeedModels';
import { PostModels, PostDetail } from '../model/PostModels';
import { GlassTheme } from '../view/GlassTheme';

@Entry
@Component
struct CommunityPage {
  @StorageLink('glassLevel') glassLevel: number = 3;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State keyword: string = '';
  @State activeKeyword: string = '';
  @State posts: FeedPost[] = [];
  @State users: FeedUser[] = [];
  @State navigators: WebHomeNavigator[] = [];
  @State loading: boolean = false;
  @State errorText: string = '';
  @State hasSearched: boolean = false;
  @State showNavigator: boolean = true;
  @State mothersLoading: boolean = true;
  @State showPostDetail: boolean = false;
  @State detailLoading: boolean = false;
  @State detailError: string = '';
  @State detail: PostDetail | null = null;

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  aboutToAppear(): void {
    this.loadNavigation();
  }

  private async loadNavigation(): Promise<void> {
    this.mothersLoading = true;
    try {
      const navList = await FeedApi.fetchWebHome(2);
      this.navigators = navList.navigators;
    } catch (e) {
      // 静默失败，不阻塞页面
    } finally {
      this.mothersLoading = false;
    }
  }

  private async search(): Promise<void> {
    if (this.keyword.trim() === '') {
      return;
    }
    this.loading = true;
    this.errorText = '';
    this.activeKeyword = this.keyword.trim();
    this.hasSearched = true;
    this.showNavigator = false;
    try {
      const raw = await FeedApi.fetchSearch(this.activeKeyword, 2, 20);
      const r = FeedModels.parseSearchMixed(raw);
      this.posts = r.posts;
      this.users = r.users;
    } catch (e) {
      this.errorText = '搜索失败，请检查网络';
    } finally {
      this.loading = false;
    }
  }

  private openUser(p: FeedPost): void {
    if (p.postId !== '') {
      router.pushUrl({ url: 'pages/PostDetail', params: { postId: p.postId } });
    }
  }

  private openUserDp(u: FeedUser): void {
    if (u.uid !== '') {
      router.pushUrl({ url: 'pages/UserProfile', params: { uid: u.uid } });
    }
  }

  @Builder
  CardAvatar(avatar: string, name: string, official: boolean) {
    if (avatar.length > 0) {
      Image(avatar)
        .width(40)
        .height(40)
        .borderRadius(20)
        .alt($r('app.media.app_icon'))
    } else {
      Row() {
        Text(name.length > 0 ? name.substring(0, 1) : '米')
          .fontSize(16)
          .fontColor('#7C3AED')
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor('#E5F6FF')
      .justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  PostCard(p: FeedPost) {
    Column({ space: 8 }) {
      if (p.cover !== '') {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image(p.cover)
            .width('100%')
            .borderRadius(12)
            .objectFit(ImageFit.Cover)
            .constraintSize({ maxHeight: 320 })
          Text(p.title !== '' ? p.title : '')
            .fontSize(14)
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
        Text(p.title)
          .fontSize(15)
          .fontColor('#101828')
          .fontWeight(FontWeight.Medium)
          .width('100%')
      }

      Row({ space: 8 }) {
        this.CardAvatar(p.authorAvatar, p.author, p.isOfficial)
        Column() {
          Text(p.author)
            .fontSize(13)
            .fontColor('#101828')
            .fontWeight(FontWeight.Medium)
          Text(p.createdAt)
            .fontSize(11)
            .fontColor('#98A2B3')
        }
        .layoutWeight(1)
        Blank()
        if (p.isOfficial) {
          Text('官')
            .fontSize(10)
            .fontColor('#1570EF')
            .backgroundColor('#E5F6FF')
            .borderRadius(4)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        }
      }
      .width('100%')

      Row({ space: 12 }) {
        Text(`浏览 ${FeedModels.formatCount(p.viewNum)}`)
          .fontSize(12)
          .fontColor('#98A2B3')
        Text(`评 ${FeedModels.formatCount(p.replyNum)}`)
          .fontSize(12)
          .fontColor('#98A2B3')
        Text(`赞 ${FeedModels.formatCount(p.likeNum)}`)
          .fontSize(12)
          .fontColor('#98A2B3')
      }
      .width('100%')
    }
    .padding(12)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(() => this.openUser(p))
  }

  @Builder
  UserCard(u: FeedUser) {
    Row({ space: 10 }) {
      if (u.avatar.length > 0) {
        Image(u.avatar)
          .width(48)
          .height(48)
          .borderRadius(24)
          .alt($r('app.media.app_icon'))
      } else {
        Row() {
          Text(u.name.length > 0 ? u.name.substring(0, 1) : '米')
            .fontSize(18)
            .fontColor('#7C3AED')
        }
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor('#E5F6FF')
        .justifyContent(FlexAlign.Center)
      }
      Column() {
        Text(u.name)
          .fontSize(15)
          .fontColor('#101828')
          .fontWeight(FontWeight.Medium)
        Text(u.label)
          .fontSize(12)
          .fontColor('#98A2B3')
          .maxLines(1)
      }
      .layoutWeight(1)
      Blank()
      Text('个人页 ›')
        .fontSize(12)
        .fontColor('#1570EF')
        .onClick(() => this.openUserDp(u))
    }
    .padding(12)
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(() => this.openUserDp(u))
  }

  @Builder
  TopBar() {
    Row({ space: 12 }) {
      Text('←').fontSize(22).fontColor('#101828')
        .onClick(() => router.back())
      Text('社区')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row({ space: 4 }) {
        Text('⚙️')
          .fontSize(14)
        Text('频道设置')
          .fontSize(13)
          .fontColor('#1570EF')
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor('#E5F6FF')
      .onClick(() => router.pushUrl({ url: 'pages/ForumHome', params: { gid: '2' } }))
    }
    .width('100%')
    .height(56 + this.vp(this.safeTopPx))
    .padding({ top: this.vp(this.safeTopPx), left: 16, right: 16 })
    .backgroundColor(GlassTheme.barColor(this.glassLevel))
    .systemMaterial(GlassTheme.material(this.glassLevel))
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F7F8FA')

      Column({ space: 10 }) {
        // 搜索框
        Row({ space: 8 }) {
          TextInput({ placeholder: '搜索帖子、用户…' })
            .layoutWeight(1)
            .height(40)
            .borderRadius(20)
            .backgroundColor('#FFFFFF')
            .padding({ left: 14 })
            .onChange((v: string) => {
              this.keyword = v;
            })
            .onSubmit(() => {
              this.search();
            })
          Text('搜索')
            .fontSize(15)
            .fontColor('#1570EF')
            .fontWeight(FontWeight.Medium)
            .onClick(() => this.search())
        }
        .padding({ left: 16, right: 16, top: 8 })

        // 内容
        Scroll() {
          Column({ space: 12 }) {
            // 频道导航（未搜索时展示）
            if (this.showNavigator && this.navigators.length > 0) {
              Scroll() {
                Row({ space: 10 }) {
                  ForEach(this.navigators, (nav: WebHomeNavigator) => {
                    Row({ space: 8 }) {
                      Image(nav.icon)
                        .width(26)
                        .height(26)
                        .borderRadius(13)
                      Text(nav.label)
                        .fontSize(13)
                        .fontColor('#344054')
                    }
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .backgroundColor('#FFFFFF')
                    .borderRadius(22)
                  })
                }
                .padding({ left: 16, right: 16 })
              }
              .scrollable(ScrollDirection.Horizontal)
              .width('100%')
              .margin({ top: 4 })
            }

            if (!this.hasSearched) {
              if (this.mothersLoading) {
                Text('加载中…')
                  .fontSize(13)
                  .fontColor('#98A2B3')
                  .padding(20)
              }
            } else {
              if (this.activeKeyword !== '') {
                Text(`“${this.activeKeyword}”的搜索结果`)
                  .fontSize(13)
                  .fontColor('#667085')
                  .width('100%')
                  .padding({ left: 16, top: 4 })
              }

              if (this.loading) {
                Text('搜索中…')
                  .fontSize(13)
                  .fontColor('#98A2B3')
                  .padding(20)
              } else if (this.errorText !== '') {
                Text(this.errorText)
                  .fontSize(13)
                  .fontColor('#667085')
                  .padding(20)
                Button('重试')
                  .onClick(() => this.search())
              } else {
                // 用户结果
                if (this.users.length > 0) {
                  Text('用户')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#101828')
                    .width('100%')
                    .padding({ left: 16, top: 4 })
                  ForEach(this.users, (u: FeedUser) => {
                    Column() {
                      this.UserCard(u)
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 4 })
                  }, (u: FeedUser) => u.uid)
                }

                // 帖子结果
                if (this.posts.length > 0) {
                  Text('帖子')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#101828')
                    .width('100%')
                    .padding({ left: 16, top: 8 })
                  ForEach(this.posts, (p: FeedPost) => {
                    Column() {
                      this.PostCard(p)
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 4 })
                  }, (p: FeedPost) => `c${p.postId}`)
                } else if (this.users.length === 0) {
                  Text('没有找到相关内容')
                    .fontSize(13)
                    .fontColor('#98A2B3')
                    .padding(20)
                }
              }
            }
          }
          .padding({ bottom: 20 + this.vp(this.safeBottomPx) })
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
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
