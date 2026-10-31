import { promptAction } from '@kit.ArkUI';
import { FeedApi } from '../net/FeedApi';
import { FeedPost, HomeResult, FeedModels, formatCount } from '../model/FeedModels';

interface Channel {
  name: string;
  gids: number;
  gameName: string;
  color: string;
}

@Component
export struct HomeTab {
  // gids 按 handover 记录与社区公认映射；gameName 用于过滤跨游戏置顶帖。
  private channelList: Channel[] = [
    { name: '原神', gids: 2, gameName: '原神', color: '#1570EF' },
    { name: '绝区零', gids: 8, gameName: '绝区零', color: '#E66900' },
    { name: '星穹铁道', gids: 6, gameName: '星穹铁道', color: '#6B5CE7' },
    { name: '崩坏3', gids: 3, gameName: '崩坏3', color: '#00A3A3' }
  ];
  @State currentChannel: number = 0;
  @State posts: FeedPost[] = [];
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State refreshing: boolean = false;
  @State noMore: boolean = false;
  @State errorText: string = '';
  @State firstLoaded: boolean = false;
  private page: number = 1;
  private requestSeq: number = 0;

  aboutToAppear(): void {
    if (!this.firstLoaded) {
      this.reload();
    }
  }

  private switchChannel(idx: number): void {
    if (this.currentChannel === idx) {
      return;
    }
    this.currentChannel = idx;
    this.posts = [];
    this.firstLoaded = false;
    this.reload();
  }

  // 剔除置顶帖里混入的跨游戏官方公告：forumName 不含当前游戏名的置顶项降权为普通帖。
  private sanitize(result: HomeResult, gameName: string): FeedPost[] {
    const list: FeedPost[] = [];
    result.posts.forEach((p: FeedPost) => {
      if (p.isTop && p.forumName !== '' && p.forumName.indexOf(gameName) === -1) {
        const ordinary = p;
        ordinary.isTop = false;
        list.push(ordinary);
      } else {
        list.push(p);
      }
    });
    const tops = list.filter((p: FeedPost) => p.isTop);
    const others = list.filter((p: FeedPost) => !p.isTop);
    return tops.concat(others);
  }

  private async reload(): Promise<void> {
    const seq = ++this.requestSeq;
    this.page = 1;
    this.noMore = false;
    this.errorText = '';
    this.refreshing = this.firstLoaded;
    this.loading = true;
    try {
      const channel = this.channelList[this.currentChannel];
      const raw = await FeedApi.fetchHome(channel.gids, 1, 20);
      if (seq !== this.requestSeq) {
        return;
      }
      const result: HomeResult = FeedModels.parseHome(raw);
      if (result.retcode === 0) {
        this.posts = this.sanitize(result, channel.gameName);
        this.firstLoaded = true;
        if (result.posts.length < 20) {
          this.noMore = true;
        }
      } else {
        this.errorText = `接口返回 ${result.retcode}（${result.message}）`;
      }
    } catch (e) {
      if (seq !== this.requestSeq) {
        return;
      }
      this.errorText = '网络异常，请检查网络后重试';
    } finally {
      if (seq === this.requestSeq) {
        this.loading = false;
        this.refreshing = false;
      }
    }
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore || this.noMore || !this.firstLoaded) {
      return;
    }
    const seq = this.requestSeq;
    this.loadingMore = true;
    const next = this.page + 1;
    try {
      const channel = this.channelList[this.currentChannel];
      const raw = await FeedApi.fetchHome(channel.gids, next, 20);
      if (seq !== this.requestSeq) {
        return;
      }
      const result: HomeResult = FeedModels.parseHome(raw);
      if (result.retcode === 0) {
        if (result.posts.length === 0) {
          this.noMore = true;
        } else {
          this.page = next;
          const merged = this.posts.slice();
          const seen = new Set<string>();
          merged.forEach((p: FeedPost) => seen.add(p.postId));
          this.sanitize(result, channel.gameName).forEach((p: FeedPost) => {
            if (!seen.has(p.postId)) {
              seen.add(p.postId);
              merged.push(p);
            }
          });
          this.posts = merged;
          if (result.posts.length < 20) {
            this.noMore = true;
          }
        }
      }
    } catch (e) {
      // 翻页失败保持现状，用户可继续上拉重试
    } finally {
      if (seq === this.requestSeq) {
        this.loadingMore = false;
      }
    }
  }

  @Builder
  MediaImage(url: string, showMore: boolean, moreCount: number) {
    Stack() {
      Image(url)
        .width('100%')
        .height(120)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
      if (showMore) {
        Column() {
          Text(`+${moreCount}`)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height(120)
        .borderRadius(8)
        .backgroundColor('#73000000')
        .justifyContent(FlexAlign.Center)
      }
    }
    .layoutWeight(1)
  }

  @Builder
  PostCard(post: FeedPost) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Image(post.avatar)
          .width(40)
          .height(40)
          .borderRadius(20)
          .alt($r('app.media.foreground'))
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(post.author)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#101828')
            if (post.isOfficial) {
              Text('官')
                .fontSize(10)
                .fontColor('#1570EF')
                .backgroundColor('#E5F6FF')
                .borderRadius(4)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            }
            if (post.isTop) {
              Text('置顶')
                .fontSize(10)
                .fontColor('#E66900')
                .backgroundColor('#FFF3E5')
                .borderRadius(4)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            }
          }
          Text(post.timeText + (post.forumName !== '' ? ' · ' + post.forumName : ''))
            .fontSize(12)
            .fontColor('#98A2B3')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      if (post.title !== '') {
        Text(post.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#101828')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      if (post.excerpt !== '') {
        Text(post.excerpt)
          .fontSize(14)
          .fontColor('#667085')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .lineHeight(21)
      }

      if (post.images.length === 1) {
        Image(post.images[0])
          .width('100%')
          .height(180)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
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
              } else {
                Blank()
              }
            }
          }
        }
        .width('100%')
      }

      if (post.topics.length > 0) {
        Row({ space: 8 }) {
          ForEach(post.topics.slice(0, 3), (t: string) => {
            Text(t)
              .fontSize(12)
              .fontColor('#475467')
              .backgroundColor('#F2F4F7')
              .borderRadius(10)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          })
        }
        .width('100%')
      }

      Row({ space: 24 }) {
        Text(`浏览 ${formatCount(post.viewNum)}`).fontSize(13).fontColor('#98A2B3')
        Text(`评论 ${formatCount(post.replyNum)}`).fontSize(13).fontColor('#98A2B3')
        Text(`点赞 ${formatCount(post.likeNum)}`).fontSize(13).fontColor('#98A2B3')
        Blank()
        Text('只读').fontSize(11).fontColor('#C0C4CC')
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .onClick(() => {
      promptAction.showToast({ message: '帖子详情将在 R2 接入', duration: 1500 });
    })
  }

  @Builder
  FooterNote() {
    Row() {
      if (this.loadingMore) {
        Text('加载更多…').fontSize(12).fontColor('#98A2B3')
      } else if (this.noMore) {
        Text('已经到底啦').fontSize(12).fontColor('#98A2B3')
      } else {
        Text('上拉加载更多').fontSize(12).fontColor('#98A2B3')
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 14, bottom: 6 })
  }

  build() {
    Column() {
      Row({ space: 4 }) {
        ForEach(this.channelList, (ch: Channel, idx: number) => {
          Column({ space: 4 }) {
            Text(ch.name)
              .fontSize(this.currentChannel === idx ? 17 : 15)
              .fontWeight(this.currentChannel === idx ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.currentChannel === idx ? ch.color : '#667085')
            Column()
              .width(18)
              .height(3)
              .borderRadius(2)
              .backgroundColor(this.currentChannel === idx ? ch.color : '#00000000')
          }
          .padding({ left: 12, right: 12, top: 10 })
          .onClick(() => this.switchChannel(idx))
        })
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      if (this.errorText !== '' && this.posts.length === 0) {
        Column({ space: 12 }) {
          Text(this.errorText).fontSize(14).fontColor('#667085')
          Button('重试').onClick(() => {
            this.reload();
          })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (!this.firstLoaded && this.loading) {
        Column() {
          Text('加载中…').fontSize(14).fontColor('#98A2B3')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.posts.length === 0 && this.firstLoaded) {
        Column() {
          Text('暂无内容').fontSize(14).fontColor('#98A2B3')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.refreshing }) {
          List({ space: 12 }) {
            ForEach(this.posts, (post: FeedPost) => {
              ListItem() {
                this.PostCard(post)
              }
            }, (post: FeedPost) => post.postId)
            ListItem() {
              this.FooterNote()
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12, bottom: 12 })
          .onReachEnd(() => {
            this.loadMore();
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
