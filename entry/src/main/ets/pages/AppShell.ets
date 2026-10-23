import { router } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import uiMaterial from '@ohos.arkui.uiMaterial';
import { MiyousheApi } from '../net/MiyousheApi';
import { PostItem, HomeCarousel, HomeTopic, DynamicPost, Stat } from '../model/MiyousheModels';
import { Format } from '../utils/Format';

interface NewsData { list?: PostItem[]; }
interface NewsResponse { retcode: number; message: string; data?: NewsData; }
interface ToolItem { name: string; description: string; url: string; }

@Entry
@Component
struct AppShell {
  @State tab: number = 0;
  @State posts: PostItem[] = [];
  @State banners: HomeCarousel[] = [];
  @State topics: HomeTopic[] = [];
  @State news: PostItem[] = [];
  @State newsType: number = 1;
  @State busy: boolean = false;
  @State newsBusy: boolean = false;
  @State error: string = '';
  @State newsError: string = '';
  @State statState: string = 'loading';
  @State page: number = 1;
  @State more: boolean = true;
  @State moreBusy: boolean = false;
  private generation: number = 0;
  private newsGeneration: number = 0;
  private readonly labels: string[] = ['社区', '官方', '工具', '我的'];
  private readonly marks: string[] = ['◈', '▤', '◇', '◎'];
  private readonly material: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN, interactive: true, lightEffect: { color: 0xFFFFFFFF }
  });
  private readonly tools: ToolItem[] = [
    { name: '原神观测枢', description: '角色、武器与攻略资料', url: 'https://www.miyoushe.com/ys/obc/' },
    { name: '提瓦特大地图', description: '资源点与探索助手', url: 'https://webstatic.mihoyo.com/ys/app/interactive-map/' },
    { name: '攻略社区', description: '查看旅行者攻略与讨论', url: 'https://www.miyoushe.com/ys/home/43' }
  ];

  aboutToAppear(): void { this.refresh(); }

  private async refresh(): Promise<void> {
    if (this.busy || this.moreBusy) { return; }
    const token: number = ++this.generation;
    this.busy = true;
    this.error = '';
    this.statState = 'loading';
    try {
      const response = await MiyousheApi.fetchHomePosts(2, 1, 20);
      const data = response.data;
      if (response.retcode !== 0 || !data) { throw new Error(response.message); }
      this.posts = data.recommended_posts ? data.recommended_posts : [];
      this.banners = data.carousels ? data.carousels : [];
      this.topics = data.recommended_topics && data.recommended_topics.list ? data.recommended_topics.list : [];
      this.page = 1;
      this.more = this.posts.length >= 20;
      this.updateStats(this.posts, token);
    } catch (e) {
      this.error = '加载失败，请点击刷新重试';
    } finally { this.busy = false; }
  }

  private async nextPage(): Promise<void> {
    if (this.busy || this.moreBusy || !this.more) { return; }
    this.moreBusy = true;
    const token: number = this.generation;
    try {
      const response = await MiyousheApi.fetchHomePosts(2, this.page + 1, 20);
      const data = response.data;
      if (response.retcode !== 0 || !data) { throw new Error(response.message); }
      const incoming: PostItem[] = data.recommended_posts ? data.recommended_posts : [];
      const seen: Set<string> = new Set(this.posts.map((p: PostItem) => p.post.post_id));
      const fresh: PostItem[] = incoming.filter((p: PostItem) => !seen.has(p.post.post_id));
      if (token !== this.generation) { return; }
      this.posts = this.posts.concat(fresh);
      this.page++;
      this.more = incoming.length >= 20 && fresh.length > 0;
      this.updateStats(fresh, token);
    } catch (e) { this.error = '加载更多失败，可再次滚动到底部重试'; }
    finally { this.moreBusy = false; }
  }

  private async updateStats(items: PostItem[], token: number): Promise<void> {
    try {
      const result: DynamicPost[] = await MiyousheApi.fetchDynamicStats(2, items.map((p: PostItem) => p.post.post_id));
      if (token !== this.generation) { return; }
      const stats: Map<string, Stat> = new Map<string, Stat>();
      result.forEach((entry: DynamicPost) => {
        if (entry.stat && Number.isFinite(entry.stat.view_num) && Number.isFinite(entry.stat.reply_num)) {
          stats.set(String(entry.post_id), entry.stat);
        }
      });
      this.posts = this.posts.map((item: PostItem): PostItem => {
        const value = stats.get(String(item.post.post_id));
        if (!value) { return item; }
        return { post: item.post, user: item.user, stat: value, forum: item.forum, topics: item.topics, statsLoaded: true };
      });
    } catch (e) { console.warn('Statistics unavailable'); }
    finally { if (token === this.generation) { this.statState = 'done'; } }
  }

  private async loadNews(type: number): Promise<void> {
    const token: number = ++this.newsGeneration;
    this.newsType = type;
    this.newsBusy = true;
    this.newsError = '';
    const request = http.createHttp();
    try {
      const response = await request.request(`https://bbs-api.miyoushe.com/post/wapi/getNewsList?gids=2&type=${type}&page_size=20`, {
        method: http.RequestMethod.GET,
        header: { 'Referer': 'https://www.miyoushe.com/', 'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json' },
        connectTimeout: 15000, readTimeout: 15000, expectDataType: http.HttpDataType.STRING
      });
      if (response.responseCode !== 200) { throw new Error('HTTP error'); }
      const parsed = JSON.parse(response.result as string) as NewsResponse;
      const data = parsed.data;
      if (parsed.retcode !== 0 || !data) { throw new Error(parsed.message); }
      if (token === this.newsGeneration) { this.news = data.list ? data.list : []; }
    } catch (e) {
      if (token === this.newsGeneration) { this.newsError = '官方资讯加载失败，请重试'; this.news = []; }
    } finally {
      request.destroy();
      if (token === this.newsGeneration) { this.newsBusy = false; }
    }
  }

  private selectTab(index: number): void {
    this.tab = index;
    if (index === 1 && this.news.length === 0 && !this.newsBusy) { this.loadNews(this.newsType); }
  }

  @Builder
  Card(item: PostItem, official: boolean) {
    Column({ space: 10 }) {
      Text(official ? '官方' : (item.forum ? item.forum.name : '社区'))
        .fontSize(11).fontColor('#2563EB').width('100%')
      Text(item.post.subject).fontSize(17).fontWeight(FontWeight.Medium)
        .fontColor('#101828').maxLines(3).width('100%')
      if (item.post.cover) {
        Image(item.post.cover).width('100%').height(160).objectFit(ImageFit.Cover).borderRadius(14)
      }
      Row() {
        Text(item.user ? item.user.nickname : '米游社').fontSize(12).fontColor('#667085').layoutWeight(1)
        Text(official ? Format.time(item.post.created_at ? item.post.created_at : 0) :
          (item.statsLoaded ? `${Format.num(item.stat.view_num)} 浏览 · ${Format.num(item.stat.reply_num)} 评论` :
            (this.statState === 'loading' ? '统计中' : '统计暂不可用')))
          .fontSize(11).fontColor('#98A2B3')
      }.width('100%')
    }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(20)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => router.pushUrl({ url: 'pages/PostDetail', params: { post_id: item.post.post_id } }))
  }

  @Builder
  Community() {
    Column() {
      Row() {
        Text('米柚 · 社区').fontSize(24).fontWeight(FontWeight.Bold)
        Blank()
        Button(this.busy ? '加载中' : '刷新').enabled(!this.busy).onClick(() => this.refresh())
      }.width('100%').padding(16)
      if (this.error) { Text(this.error).fontSize(12).fontColor('#B54708').padding(8) }
      if (this.busy && this.posts.length === 0) { LoadingProgress().width(40).height(40) }
      List({ space: 14 }) {
        if (this.banners.length > 0) {
          ListItem() {
            Swiper() {
              ForEach(this.banners, (banner: HomeCarousel) => {
                Image(banner.cover).width('100%').height(160).objectFit(ImageFit.Cover)
              }, (banner: HomeCarousel) => banner.cover)
            }.height(160).autoPlay(true).interval(4500).borderRadius(20).clip(true)
          }
        }
        if (this.topics.length > 0) {
          ListItem() {
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.topics.slice(0, 8), (topic: HomeTopic) => {
                  Text(`# ${topic.name}`).fontSize(13).fontColor('#2563EB').padding(12)
                    .backgroundColor('#EAF2FF').borderRadius(18)
                }, (topic: HomeTopic) => `${topic.id}`)
              }
            }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
          }
        }
        ListItem() {
          Text('置顶与月榜 · 完整首页').fontSize(13).fontColor('#2563EB').padding(12)
            .onClick(() => router.pushUrl({ url: 'pages/Index' }))
        }
        ForEach(this.posts, (item: PostItem) => { ListItem() { this.Card(item, false) } },
          (item: PostItem) => item.post.post_id)
        ListItem() {
          Text(this.moreBusy ? '加载更多…' : (this.more ? '继续上滑加载' : '没有更多内容'))
            .fontSize(12).fontColor('#98A2B3').padding(16).width('100%').textAlign(TextAlign.Center)
        }
      }.layoutWeight(1).width('100%').padding({ left: 16, right: 16 }).onReachEnd(() => this.nextPage())
    }.width('100%').height('100%')
  }

  @Builder
  Official() {
    Column({ space: 12 }) {
      Text('官方资讯').fontSize(24).fontWeight(FontWeight.Bold).width('100%').padding(16)
      Row({ space: 10 }) {
        ForEach(['公告', '活动', '资讯'], (name: string, index: number) => {
          Button(name).fontSize(14).backgroundColor(this.newsType === index + 1 ? '#2563EB' : '#EAF2FF')
            .fontColor(this.newsType === index + 1 ? Color.White : '#2563EB')
            .onClick(() => this.loadNews(index + 1))
        }, (name: string) => name)
      }.width('100%').justifyContent(FlexAlign.Center)
      if (this.newsBusy) { LoadingProgress().width(36).height(36) }
      if (this.newsError) {
        Text(this.newsError).fontColor('#B54708').onClick(() => this.loadNews(this.newsType))
      }
      List({ space: 12 }) {
        ForEach(this.news, (item: PostItem) => { ListItem() { this.Card(item, true) } },
          (item: PostItem) => item.post.post_id)
        if (!this.newsBusy && this.news.length === 0 && !this.newsError) { ListItem() { Text('暂无资讯').padding(20) } }
      }.width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
    }.width('100%').height('100%')
  }

  @Builder
  Tools() {
    Column({ space: 14 }) {
      Text('工具中心').fontSize(24).fontWeight(FontWeight.Bold).width('100%')
      Text('官方网页工具 · 账号功能由官方页面提供').fontSize(12).fontColor('#667085').width('100%')
      ForEach(this.tools, (tool: ToolItem) => {
        Column({ space: 8 }) {
          Text(tool.name).fontSize(18).fontWeight(FontWeight.Medium).width('100%')
          Text(tool.description).fontSize(13).fontColor('#667085').width('100%')
          Text('打开 →').fontColor('#2563EB').width('100%')
        }.width('100%').padding(18).backgroundColor(Color.White).borderRadius(20)
          .onClick(() => router.pushUrl({ url: 'pages/ToolWeb', params: { url: tool.url, title: tool.name } }))
      }, (tool: ToolItem) => tool.name)
      Blank()
    }.width('100%').height('100%').padding(16)
  }

  @Builder
  Mine() {
    Column({ space: 16 }) {
      Text('我的米柚').fontSize(26).fontWeight(FontWeight.Bold)
      Text('0.3.0 · 开发预览').fontSize(14).fontColor('#2563EB')
      Text('未登录').fontSize(20).margin({ top: 24 })
      Text('当前支持匿名浏览。登录、签到、战绩尚未接入，不会收集账号密码。')
        .fontSize(14).fontColor('#667085').textAlign(TextAlign.Center)
      Text('米柚是非官方客户端，与米哈游无隶属关系。').fontSize(12).fontColor('#98A2B3')
      Button('返回社区').onClick(() => this.selectTab(0))
      Blank()
    }.width('100%').height('100%').padding(24)
  }

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#F7F8FA')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Column() {
          if (this.tab === 0) { this.Community() }
          else if (this.tab === 1) { this.Official() }
          else if (this.tab === 2) { this.Tools() }
          else { this.Mine() }
        }.width('100%').layoutWeight(1)
        Row() {
          ForEach(this.labels, (label: string, index: number) => {
            Column({ space: 3 }) {
              Text(this.marks[index]).fontSize(22).fontColor(this.tab === index ? '#2563EB' : '#667085')
              Text(label).fontSize(11).fontColor(this.tab === index ? '#2563EB' : '#667085')
            }.layoutWeight(1).height(54).justifyContent(FlexAlign.Center)
              .borderRadius(24).backgroundColor(this.tab === index ? '#222563EB' : Color.Transparent)
              .accessibilityText(label).onClick(() => this.selectTab(index))
          }, (label: string) => label)
        }.width('92%').padding(6).margin({ top: 8, bottom: 8 }).borderRadius(32)
          .backgroundColor('#F2FFFFFF').systemMaterial(this.material)
      }.width('100%').height('100%')
    }.width('100%').height('100%')
  }
}
