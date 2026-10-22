// 原神版块帖子列表页(阶段1只读原型)
import { router } from '@kit.ArkUI';
import { MiyousheApi } from '../net/MiyousheApi';
import { PostItem } from '../model/MiyousheModels';
import { Format } from '../utils/Format';

const PAGE_SIZE: number = 20;

@Entry
@Component
struct Index {
  @State posts: PostItem[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State error: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  async refresh(): Promise<void> {
    if (this.loading) {
      return;
    }
    this.error = '';
    this.loading = true;
    try {
      const resp = await MiyousheApi.fetchHomePosts(MiyousheApi.GIDS_GENSHIN, 1, PAGE_SIZE);
      if (resp.retcode !== 0 || !resp.data) {
        throw new Error(`接口返回 ${resp.retcode}: ${resp.message}`);
      }
      const list: PostItem[] = resp.data.recommended_posts ? resp.data.recommended_posts : [];
      this.posts = list;
      this.page = 1;
      this.hasMore = list.length >= PAGE_SIZE;
    } catch (e) {
      this.posts = [];
      this.hasMore = false;
      this.error = `加载失败:${e instanceof Error ? e.message : String(e)}`;
    } finally {
      this.loading = false;
    }
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore || this.loading || !this.hasMore) {
      return;
    }
    this.loadingMore = true;
    try {
      const nextPage: number = this.page + 1;
      const resp = await MiyousheApi.fetchHomePosts(MiyousheApi.GIDS_GENSHIN, nextPage, PAGE_SIZE);
      if (resp.retcode !== 0 || !resp.data) {
        throw new Error(`接口返回 ${resp.retcode}: ${resp.message}`);
      }
      const list: PostItem[] = resp.data.recommended_posts ? resp.data.recommended_posts : [];
      // 按 post_id 去重,避免推荐流重复内容或旧响应串数据
      const existing: Set<string> = new Set(this.posts.map((p: PostItem) => p.post.post_id));
      const fresh: PostItem[] = list.filter((p: PostItem) => !existing.has(p.post.post_id));
      this.posts = this.posts.concat(fresh);
      this.page = nextPage;
      if (list.length < PAGE_SIZE) {
        this.hasMore = false;
      }
    } catch (e) {
      // 加载更多失败不阻断浏览,下次触底重试
      console.error(`loadMore failed: ${e instanceof Error ? e.message : String(e)}`);
    } finally {
      this.loadingMore = false;
    }
  }

  @Builder
  PostCard(item: PostItem) {
    Column() {
      Text(item.post.subject)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (item.post.cover && item.post.cover !== '') {
        Image(item.post.cover)
          .width('100%')
          .height(150)
          .objectFit(ImageFit.Cover)
          .borderRadius(8)
          .margin({ top: 8 })
      }
      Row() {
        if (item.user.avatar_url && item.user.avatar_url !== '') {
          Image(item.user.avatar_url)
            .width(22)
            .height(22)
            .borderRadius(11)
            .autoResize(true)
        }
        Text(item.user.nickname)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ left: 6 })
        Blank()
        Text(`${Format.num(item.stat ? item.stat.view_num : 0)} 浏览`)
          .fontSize(11)
          .fontColor('#999999')
        Text(`${Format.num(item.stat ? item.stat.reply_num : 0)} 评论`)
          .fontSize(11)
          .fontColor('#999999')
          .margin({ left: 10 })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor('#F5F6FA')
    .onClick(() => {
      router.pushUrl({ url: 'pages/PostDetail', params: { post_id: item.post.post_id } });
    })
  }

  build() {
    Column() {
      Row() {
        Text('米柚 · 原神')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button(this.loading ? '刷新中' : '刷新')
          .fontSize(13)
          .height(32)
          .enabled(!this.loading)
          .onClick(() => this.refresh())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })

      if (this.error !== '') {
        Column() {
          Text(this.error)
            .fontSize(14)
            .fontColor('#C0392B')
            .textAlign(TextAlign.Center)
          Button('重试')
            .margin({ top: 12 })
            .onClick(() => this.refresh())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.posts.length === 0 && this.loading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.posts.length === 0) {
        Column() {
          Text('暂无内容')
            .fontSize(14)
            .fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.posts, (item: PostItem) => {
            ListItem() {
              this.PostCard(item)
            }
          }, (item: PostItem) => item.post.post_id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .onReachEnd(() => this.loadMore())

        if (this.loadingMore) {
          LoadingProgress()
            .width(28)
            .height(28)
            .margin(12)
        } else if (!this.hasMore) {
          Text('没有更多了')
            .fontSize(12)
            .fontColor('#BBBBBB')
            .margin(12)
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}
