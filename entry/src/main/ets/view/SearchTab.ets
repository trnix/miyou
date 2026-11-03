import { router } from '@kit.ArkUI';
import { SearchApi, SearchPost } from '../net/SearchApi';

@Component
export struct SearchTab {
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State keyword: string = '';
  @State game: number = 0;
  @State order: number = 1;
  @State posts: SearchPost[] = [];
  @State loading: boolean = false;
  @State errorText: string = '';
  @State searched: boolean = false;
  @State end: boolean = true;
  private cursor: string = '';
  private submitted: string = '';
  private epoch: number = 0;
  private games: string[] = ['原神', '星穹铁道', '绝区零'];
  private gids: string[] = ['2', '6', '8'];

  aboutToDisappear(): void {
    this.epoch++;
    this.loading = false;
  }

  private async run(more: boolean): Promise<void> {
    if (more && (this.loading || this.end)) { return; }
    const q = more ? this.submitted : this.keyword.trim();
    if (q === '') {
      this.epoch++;
      this.loading = false;
      this.posts = [];
      this.searched = false;
      this.end = true;
      this.cursor = '';
      this.errorText = '请输入搜索关键词';
      return;
    }
    const epoch = ++this.epoch;
    const gid = this.gids[this.game];
    const order = this.order;
    const cursor = more ? this.cursor : '';
    if (!more) {
      this.posts = [];
      this.cursor = '';
      this.submitted = q;
      this.end = true;
      this.searched = false;
    }
    this.loading = true;
    this.errorText = '';
    try {
      const r = await SearchApi.search(gid, q, cursor, order);
      if (epoch !== this.epoch) { return; }
      const merged: SearchPost[] = more ? this.posts.slice() : [];
      const seen = new Set<string>();
      merged.forEach((p: SearchPost) => { seen.add(p.id); });
      r.posts.forEach((p: SearchPost) => {
        if (!seen.has(p.id)) { seen.add(p.id); merged.push(p); }
      });
      this.end = r.end || (more && merged.length === this.posts.length);
      this.posts = merged;
      this.cursor = r.cursor;
      this.searched = true;
    } catch (e) {
      if (epoch === this.epoch) {
        this.errorText = (e as Error).message || '请求失败，请重试';
      }
    } finally {
      if (epoch === this.epoch) { this.loading = false; }
    }
  }

  build() {
    Column({ space: 12 }) {
      Text('帖子搜索').fontSize(20).fontWeight(FontWeight.Medium)
      Row({ space: 8 }) {
        TextInput({ placeholder: '输入关键词', text: this.keyword })
          .layoutWeight(1)
          .onChange((v: string) => { this.keyword = v; })
          .onSubmit(() => { this.run(false); })
        Button('搜索').onClick(() => { this.run(false); })
      }.width('100%')
      Row({ space: 8 }) {
        ForEach(this.games, (name: string, idx: number) => {
          Text(name).fontSize(12)
            .fontColor(this.game === idx ? '#1570EF' : '#667085')
            .padding(8).backgroundColor(this.game === idx ? '#E5F6FF' : '#FFFFFF')
            .borderRadius(10)
            .onClick(() => {
              if (this.game !== idx) { this.game = idx; this.run(false); }
            })
        })
      }.width('100%')
      Row({ space: 16 }) {
        Text('最热').fontColor(this.order === 1 ? '#1570EF' : '#667085')
          .onClick(() => { if (this.order !== 1) { this.order = 1; this.run(false); } })
        Text('最新').fontColor(this.order === 2 ? '#1570EF' : '#667085')
          .onClick(() => { if (this.order !== 2) { this.order = 2; this.run(false); } })
      }.width('100%')
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
              .onClick(() => { router.pushUrl({ url: 'pages/PostDetail', params: { postId: p.id } }); })
          }
        }, (p: SearchPost) => p.id)
        ListItem() {
          Column({ space: 10 }) {
            if (this.loading) {
              Text('搜索中…').fontColor('#667085')
            } else if (this.errorText !== '') {
              Text(this.errorText).fontColor('#667085').fontSize(13)
              Button('重试').onClick(() => { this.run(this.posts.length > 0); })
            } else if (!this.searched) {
              Text('选择频道，输入关键词开始搜索').fontColor('#98A2B3')
            } else if (this.posts.length === 0) {
              Text('没有找到相关帖子').fontColor('#98A2B3')
            } else if (!this.end) {
              Button('加载更多').onClick(() => { this.run(true); })
            } else {
              Text('已显示全部结果或分页已停止').fontSize(12).fontColor('#98A2B3')
            }
          }.width('100%').padding({ top: 16, bottom: 110 + this.getUIContext().px2vp(this.safeBottomPx) })
        }
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').padding({ left: 16, right: 16, top: 12 })
  }
}
