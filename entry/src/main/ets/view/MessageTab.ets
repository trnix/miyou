import { router } from '@kit.ArkUI';
import { Session } from '../auth/Session';
import { NotifyApi } from '../net/NotifyApi';
import { NotifyModels, NotifyItem, MessageCnt } from '../model/NotifyModels';

interface EntryDef {
  label: string;
  icon: string;
  type: number;
}

// R3 消息中心（只读）：聊天/通知双 tab + 三快捷入口 + 分类通知列表。
// 聊天为协议性不做（IM 私有协议）；通知接口为候选端点，失败时出诊断卡。
@Component
export struct MessageTab {
  @StorageLink('cookie') cookie: string = '';
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State segIndex: number = 1; // 默认落在通知 tab
  @State cnt: MessageCnt = { replyAt: 0, praise: 0, follow: 0, total: 0 };
  @State activeType: number = 1;
  @State items: NotifyItem[] = [];
  @State loading: boolean = false;
  @State errorText: string = '';
  @State lastId: string = '';
  @State isLast: boolean = true;
  @State loaded: boolean = false;
  private entries: EntryDef[] = [
    { label: '评论和@', icon: '💬', type: 1 },
    { label: '新增关注', icon: '👤', type: 3 },
    { label: '收到的赞', icon: '👍', type: 2 }
  ];

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  aboutToAppear(): void {
    if (Session.loggedIn()) {
      this.loadCnt();
      this.loadList(false);
    }
  }

  private entryCnt(type: number): number {
    if (type === 1) {
      return this.cnt.replyAt;
    }
    if (type === 2) {
      return this.cnt.praise;
    }
    return this.cnt.follow;
  }

  private async loadCnt(): Promise<void> {
    try {
      const raw = await NotifyApi.fetchMessageCnt();
      if (raw.httpCode === 200) {
        this.cnt = NotifyModels.parseCnt(raw.body);
        AppStorage.setOrCreate('msgUnreadTotal', this.cnt.total);
      }
    } catch (e) {
      // 计数失败不阻塞列表
    }
  }

  private async loadList(more: boolean): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    if (!more) {
      this.errorText = '';
    }
    try {
      const raw = await NotifyApi.fetchNotifyList(this.activeType, more ? this.lastId : '', 20);
      const r = NotifyModels.parseList(raw.body);
      if (raw.httpCode === 200 && r.retcode === 0) {
        this.lastId = r.lastId;
        this.isLast = r.isLast;
        if (more) {
          const merged = this.items.slice();
          const seen = new Set<string>();
          merged.forEach((x: NotifyItem) => seen.add(x.id));
          r.items.forEach((x: NotifyItem) => {
            if (!seen.has(x.id)) {
              seen.add(x.id);
              merged.push(x);
            }
          });
          this.items = merged;
        } else {
          this.items = r.items;
        }
        this.loaded = true;
        this.errorText = '';
      } else {
        this.errorText = `接口未命中（候选端点待校准）\nHTTP ${raw.httpCode} · retcode ${r.retcode}（${r.message}）\n${NotifyApi.trimBody(raw.body)}`;
      }
    } catch (e) {
      this.errorText = '网络异常，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  @Builder
  SegTabs() {
    Row({ space: 8 }) {
      ForEach(['聊天', '通知'], (label: string, idx: number) => {
        Stack({ alignContent: Alignment.TopEnd }) {
          Text(label)
            .fontSize(15)
            .fontWeight(this.segIndex === idx ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.segIndex === idx ? '#1570EF' : '#667085')
            .padding({ left: 20, right: 20, top: 8, bottom: 8 })
          if (idx === 1 && this.cnt.total > 0) {
            Text(this.cnt.total > 99 ? '99+' : this.cnt.total.toString())
              .fontSize(9)
              .fontColor('#FFFFFF')
              .backgroundColor('#FA2A19')
              .borderRadius(8)
              .padding({ left: 4, right: 4 })
              .margin({ top: 2, right: 6 })
          }
        }
        .backgroundColor(this.segIndex === idx ? '#2B1570EF' : '#00000000')
        .borderRadius(18)
        .onClick(() => {
          this.segIndex = idx;
        })
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 8, bottom: 4 })
  }

  @Builder
  ChatFallback() {
    Column({ space: 12 }) {
      Text('💬')
        .fontSize(44)
      Text('聊天暂不可用')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
      Text('米游社私信由官方自研 IM 长连接协议承载，无法以只读 HTTP 接口提供。请使用官方 App 收发私信；评论、点赞、关注等通知可在「通知」页查看。')
        .fontSize(13)
        .fontColor('#667085')
        .textAlign(TextAlign.Center)
        .lineHeight(20)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(32)
  }

  @Builder
  EntryRow() {
    Row() {
      ForEach(this.entries, (e: EntryDef) => {
        Column({ space: 6 }) {
          Stack({ alignContent: Alignment.TopEnd }) {
            Text(e.icon)
              .fontSize(26)
              .width(52)
              .height(52)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.activeType === e.type ? '#E5F6FF' : '#F2F4F7')
              .borderRadius(26)
            if (this.entryCnt(e.type) > 0) {
              Text(this.entryCnt(e.type) > 99 ? '99+' : this.entryCnt(e.type).toString())
                .fontSize(9)
                .fontColor('#FFFFFF')
                .backgroundColor('#FA2A19')
                .borderRadius(8)
                .padding({ left: 4, right: 4 })
            }
          }
          Text(e.label)
            .fontSize(12)
            .fontColor(this.activeType === e.type ? '#1570EF' : '#475467')
        }
        .layoutWeight(1)
        .onClick(() => {
          if (this.activeType !== e.type) {
            this.activeType = e.type;
            this.items = [];
            this.lastId = '';
            this.isLast = true;
            this.loaded = false;
            this.loadList(false);
          }
        })
      })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
  }

  @Builder
  NotifyView(item: NotifyItem) {
    Row({ space: 10 }) {
      Image(item.avatar)
        .width(44)
        .height(44)
        .borderRadius(22)
        .alt($r('app.media.app_icon'))
      Column({ space: 3 }) {
        Text(item.nickname !== '' ? item.nickname : '米游社用户')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#101828')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.content !== '' ? item.content : '（暂无摘要）')
          .fontSize(13)
          .fontColor('#667085')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Column({ space: 6 }) {
        Text(item.timeText)
          .fontSize(11)
          .fontColor('#98A2B3')
        if (item.isNew) {
          Circle()
            .width(8)
            .height(8)
            .fill('#1570EF')
        }
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .onClick(() => {
      if (item.postId !== '') {
        router.pushUrl({ url: 'pages/PostDetail', params: { postId: item.postId } });
      }
    })
  }

  @Builder
  NotifyBody() {
    if (this.items.length === 0 && this.loading) {
      Text('加载中…')
        .fontSize(13)
        .fontColor('#98A2B3')
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 40 })
    } else if (this.items.length === 0 && this.errorText !== '') {
      Column({ space: 10 }) {
        Text('通知列表加载失败')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Text(this.errorText)
          .fontSize(12)
          .fontColor('#667085')
          .width('100%')
          .lineHeight(18)
          .copyOption(CopyOptions.LocalDevice)
        Button('重试')
          .onClick(() => this.loadList(false))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(14)
    } else if (this.items.length === 0 && this.loaded) {
      Text('暂无通知')
        .fontSize(13)
        .fontColor('#98A2B3')
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 40 })
    } else {
      ForEach(this.items, (item: NotifyItem) => {
        this.NotifyView(item)
      }, (item: NotifyItem) => item.id)
      if (!this.isLast) {
        Button(this.loading ? '加载中…' : '加载更多')
          .enabled(!this.loading)
          .onClick(() => this.loadList(true))
      }
    }
  }

  build() {
    Column({ space: 12 }) {
      this.SegTabs()
      if (!Session.loggedIn()) {
        Column({ space: 12 }) {
          Text('消息中心需要登录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          Text('登录后可查看评论、点赞、关注通知')
            .fontSize(13)
            .fontColor('#667085')
          Button('去登录')
            .onClick(() => router.pushUrl({ url: 'pages/Login' }))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.segIndex === 0) {
        this.ChatFallback()
      } else {
        Scroll() {
          Column({ space: 10 }) {
            this.EntryRow()
            this.NotifyBody()
          }
          .width('100%')
          .padding({ bottom: 100 + this.vp(this.safeBottomPx) })
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }
}
