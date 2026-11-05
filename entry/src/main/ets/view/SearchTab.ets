import { router } from '@kit.ArkUI';
import { SearchApi, SearchPost } from '../net/SearchApi';
import { GameInfo, gameByGids, defaultOrder, cleanOrder } from '../net/GameCatalog';

@Component
export struct SearchTab {
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @StorageLink('searchChannelOrder') @Watch('onChannelsChanged') searchOrder: number[] = [];
  @State keyword: string = '';
  @State currentGid: number = 2;
  @State order: number = 1;
  @State posts: SearchPost[] = [];
  @State loading: boolean = false;
  @State errorText: string = '';
  @State searched: boolean = false;
  @State end: boolean = true;
  private cursor: string = '';
  private submitted: string = '';
  private epoch: number = 0;
  private active: boolean = false;

  private channelList(): GameInfo[] {
    const ids = this.searchOrder.length > 0 ? cleanOrder(this.searchOrder) : defaultOrder();
    return ids.map((id: number) => gameByGids(id));
  }

  onChannelsChanged(): void {
    if (!this.active) { return; }
    const ids = this.searchOrder.length > 0 ? cleanOrder(this.searchOrder) : defaultOrder();
    if (ids.indexOf(this.currentGid) < 0) { this.select(ids[0]); }
  }

  aboutToAppear(): void { this.active = true; this.onChannelsChanged(); }
  aboutToDisappear(): void { this.active = false; this.epoch++; this.loading = false; }

  private select(id: number): void {
    if (this.currentGid === id) { return; }
    this.currentGid = id;
    this.epoch++;
    this.loading = false;
    this.posts = [];
    this.cursor = '';
    this.submitted = '';
    this.searched = false;
    this.end = true;
    this.errorText = '';
    if (this.keyword.trim() !== '') { this.run(false); }
  }

  private async run(more: boolean): Promise<void> {
    if (more && (this.loading || this.end)) { return; }
    if (!more) { this.getUIContext().getFocusController().clearFocus(); }
    const q = more ? this.submitted : this.keyword.trim();
    if (q === '') {
      this.epoch++; this.loading = false; this.posts = []; this.searched = false;
      this.end = true; this.cursor = ''; this.errorText = '请输入搜索关键词'; return;
    }
    const epoch = ++this.epoch;
    const gid = this.currentGid.toString();
    const order = this.order;
    const cursor = more ? this.cursor : '';
    if (!more) {
      this.posts = []; this.cursor = ''; this.submitted = q; this.end = true; this.searched = false;
    }
    this.loading = true; this.errorText = '';
    try {
      const r = await SearchApi.search(gid, q, cursor, order);
      if (epoch !== this.epoch) { return; }
      const merged: SearchPost[] = more ? this.posts.slice() : [];
      const seen = new Set<string>();
      merged.forEach((p: SearchPost) => { seen.add(p.id); });
      r.posts.forEach((p: SearchPost) => {
        if (!seen.has(p.id)) { seen.add(p.id); merged.push(p); }
      });
      this.end = r.end || (more && (merged.length === this.posts.length || r.cursor === cursor));
      this.posts = merged; this.cursor = r.cursor; this.searched = true;
    } catch (e) {
      if (epoch === this.epoch) { this.errorText = (e as Error).message || '请求失败，请重试'; }
    } finally { if (epoch === this.epoch) { this.loading = false; } }
  }

  build() {
    Column({ space: 12 }) {
      Text('帖子搜索').fontSize(20).fontWeight(FontWeight.Medium)
      Row({ space: 8 }) {
        TextInput({ placeholder: '输入关键词', text: this.keyword }).layoutWeight(1)
          .onChange((v: string) => { this.keyword = v; }).onSubmit(() => this.run(false))
        Button('搜索').onClick(() => this.run(false))
      }.width('100%')
      Row({ space: 8 }) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.channelList(), (g: GameInfo) => {
              Text(g.short).fontSize(12).maxLines(1).flexShrink(0)
                .fontColor(this.currentGid === g.gids ? '#1570EF' : '#667085')
                .padding(8).backgroundColor(this.currentGid === g.gids ? '#E5F6FF' : '#FFFFFF')
                .borderRadius(10).onClick(() => this.select(g.gids))
            }, (g: GameInfo) => g.gids.toString())
          }
        }.layoutWeight(1).height(40).scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off).align(Alignment.Start)
        Button('频道', { type: ButtonType.Capsule }).fontSize(13).width(64).height(32)
          .backgroundColor('#1570EF').fontColor('#FFFFFF')
          .onClick(() => router.pushUrl({ url: 'pages/ChannelManage', params: { target: 'search' } }))
      }.width('100%')
      // 最热 / 最新：居中胶囊，更大字号与点击区，两枚拉开间距
      Row({ space: 28 }) {
        Text('最热')
          .fontSize(14)
          .fontColor(this.order === 1 ? '#FFFFFF' : '#667085')
          .fontWeight(this.order === 1 ? FontWeight.Medium : FontWeight.Normal)
          .padding({ left: 22, right: 22, top: 8, bottom: 8 })
          .backgroundColor(this.order === 1 ? '#1570EF' : '#F2F4F7')
          .borderRadius(19)
          .onClick(() => { if (this.order !== 1) { this.order = 1; this.run(false); } })
        Text('最新')
          .fontSize(14)
          .fontColor(this.order === 2 ? '#FFFFFF' : '#667085')
          .fontWeight(this.order === 2 ? FontWeight.Medium : FontWeight.Normal)
          .padding({ left: 22, right: 22, top: 8, bottom: 8 })
          .backgroundColor(this.order === 2 ? '#1570EF' : '#F2F4F7')
          .borderRadius(19)
          .onClick(() => { if (this.order !== 2) { this.order = 2; this.run(false); } })
      }.width('100%').justifyContent(FlexAlign.Center)
      List({ space: 10 }) {
        ForEach(this.posts, (p: SearchPost) => {
          ListItem() {
            Column({ space: 6 }) {
              Text(p.title || '无标题帖子').fontSize(17).fontWeight(FontWeight.Medium)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(p.author || '米游社用户').fontSize(12).fontColor('#667085')
              Text(p.excerpt).fontSize(14).fontColor('#667085')
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`评论 ${p.replies} · 赞 ${p.likes}`).fontSize(12).fontColor('#98A2B3')
            }.width('100%').alignItems(HorizontalAlign.Start).padding(14)
              .backgroundColor('#FFFFFF').borderRadius(14)
              .onClick(() => router.pushUrl({ url: 'pages/PostDetail', params: { postId: p.id } }))
          }
        }, (p: SearchPost) => p.id)
        ListItem() {
          Column({ space: 10 }) {
            if (this.loading) { Text('搜索中…').fontColor('#667085') }
            else if (this.errorText !== '') {
              Text(this.errorText).fontColor('#667085').fontSize(13)
              Button('重试').onClick(() => this.run(this.posts.length > 0))
            } else if (!this.searched) { Text('选择频道，输入关键词开始搜索').fontColor('#98A2B3') }
            else if (this.posts.length === 0) { Text('没有找到相关帖子').fontColor('#98A2B3') }
            else if (!this.end) { Button('加载更多').onClick(() => this.run(true)) }
            else { Text('已显示全部结果或分页已停止').fontSize(12).fontColor('#98A2B3') }
          }.width('100%').padding({ top: 16, bottom: 110 + this.getUIContext().px2vp(this.safeBottomPx) })
        }
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 12 })
  }
}
