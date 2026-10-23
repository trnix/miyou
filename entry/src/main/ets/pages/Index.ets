// 0.2.0 首页：轮播、话题、置顶、月榜，以及可降级沉浸光感材质。
import { router } from '@kit.ArkUI';
import uiMaterial from '@ohos.arkui.uiMaterial';
import { MiyousheApi } from '../net/MiyousheApi';
import {
  DynamicPost,
  HomeCarousel,
  HomeTopic,
  PostItem,
  SelectionPost,
  Stat
} from '../model/MiyousheModels';
import { Format } from '../utils/Format';

const PAGE_SIZE: number = 20;

@Entry
@Component
struct Index {
  @State posts: PostItem[] = [];
  @State fixedPosts: PostItem[] = [];
  @State carousels: HomeCarousel[] = [];
  @State topics: HomeTopic[] = [];
  @State selectionPosts: SelectionPost[] = [];
  @State page: number = 1;
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State error: string = '';

  private readonly chromeMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    materialColor: 0xE8FFFFFF,
    colorInvert: false,
    applyShadow: true,
    interactive: true,
    lightEffect: { color: 0x80FFFFFF }
  })

  private readonly cardMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.REGULAR,
    materialColor: 0xEFFFFFFF,
    colorInvert: false,
    applyShadow: true,
    interactive: true,
    lightEffect: { color: 0x80FFFFFF }
  })

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
      const data = resp.data;
      if (resp.retcode !== 0 || !data) {
        throw new Error(`接口返回 ${resp.retcode}: ${resp.message}`);
      }
      const list: PostItem[] = data.recommended_posts ? data.recommended_posts : [];
      this.posts = list;
      this.fixedPosts = data.fixed_posts ? data.fixed_posts : [];
      this.carousels = data.carousels ? data.carousels : [];
      this.topics = data.recommended_topics && data.recommended_topics.list ? data.recommended_topics.list : [];
      this.selectionPosts = data.selection_post_list ? data.selection_post_list : [];
      this.page = 1;
      this.hasMore = list.length >= PAGE_SIZE;
      this.applyDynamicStats(list.concat(this.fixedPosts));
    } catch (e) {
      this.posts = [];
      this.fixedPosts = [];
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
      const data = resp.data;
      if (resp.retcode !== 0 || !data) {
        throw new Error(`接口返回 ${resp.retcode}: ${resp.message}`);
      }
      const list: PostItem[] = data.recommended_posts ? data.recommended_posts : [];
      const existing: Set<string> = new Set(this.posts.map((item: PostItem) => item.post.post_id));
      const fresh: PostItem[] = list.filter((item: PostItem) => !existing.has(item.post.post_id));
      this.posts = this.posts.concat(fresh);
      this.page = nextPage;
      if (list.length < PAGE_SIZE) {
        this.hasMore = false;
      }
      this.applyDynamicStats(fresh);
    } catch (e) {
      console.error(`loadMore failed: ${e instanceof Error ? e.message : String(e)}`);
    } finally {
      this.loadingMore = false;
    }
  }

  private applyDynamicStats(items: PostItem[]): void {
    if (items.length === 0) {
      return;
    }
    this.loadDynamicStats(items);
  }

  private async loadDynamicStats(items: PostItem[]): Promise<void> {
    const ids: string[] = items.map((item: PostItem) => item.post.post_id);
    const dynamicPosts: DynamicPost[] = await MiyousheApi.fetchDynamicStats(MiyousheApi.GIDS_GENSHIN, ids);
    const stats: Map<string, Stat> = new Map<string, Stat>();
    dynamicPosts.forEach((entry: DynamicPost) => {
      const value = entry.stat;
      if (value && Number.isFinite(value.view_num) && value.view_num >= 0 &&
        Number.isFinite(value.reply_num) && value.reply_num >= 0 &&
        Number.isFinite(value.like_num) && value.like_num >= 0) {
        stats.set(String(entry.post_id), value);
      }
    });
    this.posts = this.mergeStats(this.posts, stats);
    this.fixedPosts = this.mergeStats(this.fixedPosts, stats);
  }

  private mergeStats(items: PostItem[], stats: Map<string, Stat>): PostItem[] {
    return items.map((item: PostItem) => {
      const value = stats.get(String(item.post.post_id));
      if (!value) {
        return item;
      }
      return {
        post: item.post,
        user: item.user,
        stat: value,
        forum: item.forum,
        topics: item.topics,
        statsLoaded: true
      };
    });
  }

  @Builder
  TopBar() {
    Row() {
      Column() {
        Text('米柚')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Text('原神社区 · 发现新内容')
          .fontSize(12)
          .fontColor('#667085')
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Button(this.loading ? '刷新中' : '刷新')
        .fontSize(13)
        .height(34)
        .enabled(!this.loading)
        .onClick(() => this.refresh())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .margin({ left: 16, right: 16, top: 8, bottom: 12 })
    .borderRadius(22)
    .backgroundColor('#F5F6FA')
    .clip(true)
    .systemMaterial(this.chromeMaterial)
  }

  @Builder
  CarouselModule() {
    Swiper() {
      ForEach(this.carousels, (item: HomeCarousel) => {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image(item.cover)
            .width('100%')
            .height(168)
            .objectFit(ImageFit.Cover)
          Text('原神 · 官方精选')
            .fontSize(12)
            .fontColor(Color.White)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .margin({ left: 10, bottom: 10 })
            .borderRadius(12)
            .backgroundColor('#66000000')
        }
        .width('100%')
        .height(168)
        .clip(true)
      }, (item: HomeCarousel) => item.cover)
    }
    .width('100%')
    .height(168)
    .autoPlay(true)
    .loop(true)
    .interval(4500)
    .borderRadius(18)
    .clip(true)
  }

  @Builder
  TopicModule() {
    Column() {
      Text('推荐话题')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      List({ space: 8 }) {
        ForEach(this.topics.slice(0, 8), (topic: HomeTopic) => {
          ListItem() {
            Stack({ alignContent: Alignment.BottomStart }) {
              Image(topic.cover)
                .width(142)
                .height(58)
                .objectFit(ImageFit.Cover)
              Text(`# ${topic.name}`)
                .fontSize(12)
                .fontColor(Color.White)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .margin({ left: 6, right: 6, bottom: 6 })
                .borderRadius(10)
                .backgroundColor('#6B000000')
            }
            .width(142)
            .height(58)
            .borderRadius(14)
            .clip(true)
          }
        }, (topic: HomeTopic) => `${topic.id}`)
      }
      .width('100%')
      .height(58)
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(12)
    .borderRadius(18)
    .backgroundColor('#F5F6FA')
    .clip(true)
    .systemMaterial(this.cardMaterial)
  }

  @Builder
  FixedPostsModule() {
    Column() {
      Row() {
        Text('置顶')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('社区重点')
          .fontSize(11)
          .fontColor('#98A2B3')
      }
      .width('100%')
      ForEach(this.fixedPosts.slice(0, 2), (item: PostItem) => {
        Row() {
          Text('TOP')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#B54708')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor('#FFF4E5')
          Text(item.post.subject)
            .fontSize(14)
            .fontColor('#344054')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width('100%')
        .padding({ top: 9, bottom: 9 })
        .onClick(() => router.pushUrl({ url: 'pages/PostDetail', params: { post_id: item.post.post_id } }))
      }, (item: PostItem) => `fixed-${item.post.post_id}`)
    }
    .width('100%')
    .padding(12)
    .borderRadius(18)
    .backgroundColor('#F5F6FA')
    .clip(true)
    .systemMaterial(this.cardMaterial)
  }

  @Builder
  SelectionModule() {
    Column() {
      Row() {
        Text('每月热榜')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('本月精选')
          .fontSize(11)
          .fontColor('#98A2B3')
      }
      .width('100%')
      ForEach(this.selectionPosts.slice(0, 3), (item: SelectionPost, index: number) => {
        Row({ space: 10 }) {
          if (item.banner) {
            Image(item.banner)
              .width(58)
              .height(42)
              .objectFit(ImageFit.Cover)
              .borderRadius(10)
          }
          Column() {
            Text(item.subject)
              .fontSize(14)
              .fontColor('#344054')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(item.forum_name ? item.forum_name : `第 ${index + 1} 位`)
              .fontSize(11)
              .fontColor('#98A2B3')
              .margin({ top: 3 })
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .onClick(() => router.pushUrl({ url: 'pages/PostDetail', params: { post_id: item.post_id } }))
      }, (item: SelectionPost) => `selection-${item.post_id}`)
    }
    .width('100%')
    .padding(12)
    .borderRadius(18)
    .backgroundColor('#F5F6FA')
    .clip(true)
    .systemMaterial(this.cardMaterial)
  }

  @Builder
  PostCard(item: PostItem) {
    Column() {
      Row() {
        if (item.forum && item.forum.name) {
          Text(item.forum.name)
            .fontSize(10)
            .fontColor('#175CD3')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor('#EAF2FF')
        }
        if (item.post.post_status && item.post.post_status.is_official) {
          Text('官方')
            .fontSize(10)
            .fontColor('#B54708')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .backgroundColor('#FFF4E5')
            .margin({ left: 6 })
        }
        if (item.post.created_at) {
          Text(Format.time(item.post.created_at))
            .fontSize(10)
            .fontColor('#98A2B3')
            .margin({ left: 6 })
        }
      }
      .width('100%')

      Text(item.post.subject)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#101828')
        .lineHeight(23)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })

      if (item.post.cover && item.post.cover !== '') {
        Image(item.post.cover)
          .width('100%')
          .height(164)
          .objectFit(ImageFit.Cover)
          .borderRadius(14)
          .margin({ top: 10 })
      }

      Row() {
        if (item.user.avatar_url && item.user.avatar_url !== '') {
          Image(item.user.avatar_url)
            .width(24)
            .height(24)
            .borderRadius(12)
            .autoResize(true)
        }
        Text(item.user.nickname)
          .fontSize(12)
          .fontColor('#667085')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 7 })
          .layoutWeight(1)
        Text(item.statsLoaded ? `${Format.num(item.stat.view_num)} 浏览` : '统计中')
          .fontSize(11)
          .fontColor('#98A2B3')
        Text(item.statsLoaded ? `${Format.num(item.stat.reply_num)} 评论` : '')
          .fontSize(11)
          .fontColor('#98A2B3')
          .margin({ left: 10 })
      }
      .width('100%')
      .margin({ top: 10 })

      if (item.topics && item.topics.length > 0) {
        Row() {
          ForEach(item.topics.slice(0, 2), (topic: HomeTopic) => {
            Text(`#${topic.name}`)
              .fontSize(10)
              .fontColor('#175CD3')
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .borderRadius(8)
              .backgroundColor('#EAF2FF')
              .margin({ right: 6 })
          }, (topic: HomeTopic) => `${item.post.post_id}-${topic.id}`)
        }
        .width('100%')
        .margin({ top: 10 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .borderRadius(20)
    .backgroundColor('#F5F6FA')
    .clip(true)
    .systemMaterial(this.cardMaterial)
    .onClick(() => router.pushUrl({ url: 'pages/PostDetail', params: { post_id: item.post.post_id } }))
  }

  @Builder
  Footer() {
    if (this.loadingMore) {
      Row({ space: 8 }) {
        LoadingProgress()
          .width(22)
          .height(22)
        Text('正在加载')
          .fontSize(12)
          .fontColor('#98A2B3')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(14)
    } else if (!this.hasMore) {
      Text('已经看到这里了')
        .fontSize(12)
        .fontColor('#B0B7C3')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(14)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F7F8FA')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        this.TopBar()
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
            Text('正在进入提瓦特')
              .fontSize(13)
              .fontColor('#98A2B3')
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.posts.length === 0) {
          Column() {
            Text('暂无内容')
              .fontSize(14)
              .fontColor('#999999')
            Button('刷新')
              .margin({ top: 12 })
              .onClick(() => this.refresh())
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 12 }) {
            if (this.carousels.length > 0) {
              ListItem() {
                this.CarouselModule()
              }
            }
            if (this.topics.length > 0) {
              ListItem() {
                this.TopicModule()
              }
            }
            if (this.fixedPosts.length > 0) {
              ListItem() {
                this.FixedPostsModule()
              }
            }
            if (this.selectionPosts.length > 0) {
              ListItem() {
                this.SelectionModule()
              }
            }
            ListItem() {
              Text('推荐帖子')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#344054')
                .width('100%')
                .margin({ top: 4, bottom: -2 })
            }
            ForEach(this.posts, (item: PostItem) => {
              ListItem() {
                this.PostCard(item)
              }
            }, (item: PostItem) => item.post.post_id)
            ListItem() {
              this.Footer()
            }
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, bottom: 16 })
          .scrollBar(BarState.Off)
          .onReachEnd(() => this.loadMore())
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
