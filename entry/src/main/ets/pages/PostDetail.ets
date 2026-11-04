import { router } from '@kit.ArkUI';
import { PostApi } from '../net/PostApi';
import { PostModels, PostDetail, PostBlock } from '../model/PostModels';
import { ReplyModels, ReplyItem } from '../model/ReplyModels';
import { GlassTheme } from '../view/GlassTheme';
import { formatCount } from '../model/FeedModels';

interface RouteParams {
  postId?: string;
}

// 楼中楼展开状态：每楼层独立维护子回复列表、展开标志、分页游标与页面内 error 状态。
interface SubFloorState {
  expanded: boolean;
  loading: boolean;
  loaded: boolean;
  replies: ReplyItem[];
  lastId: string;
  isLast: boolean;
  errorText: string;
}

function emptyFloorState(): SubFloorState {
  return { expanded: false, loading: false, loaded: false, replies: [], lastId: '', isLast: true, errorText: '' };
}

@Entry
@Component
struct PostDetailPage {
  @StorageLink('glassLevel') glassLevel: number = 3;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State detail: PostDetail | null = null;
  @State loading: boolean = true;
  @State errorText: string = '';
  @State previewUrl: string = '';
  @State showPreview: boolean = false;
  @State replies: ReplyItem[] = [];
  @State replyLoading: boolean = false;
  @State replyError: string = '';
  @State replyLastId: string = '';
  @State replyIsLast: boolean = true;
  @State replyLoaded: boolean = false;
  @State floorStates: Map<string, SubFloorState> = new Map<string, SubFloorState>();
  private postId: string = '';

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  // 普通方法（非 Builder）与 Map 读操作，Builder 内只调用这两种入口，保证首层是 UI 组件语法。
  private floorStateOf(replyId: string): SubFloorState {
    const s = this.floorStates.get(replyId);
    return s === undefined ? emptyFloorState() : s;
  }

  private isFloorExpanded(replyId: string): boolean {
    const s = this.floorStates.get(replyId);
    return s === undefined ? false : s.expanded;
  }

  aboutToAppear(): void {
    const params = router.getParams() as RouteParams | undefined;
    this.postId = params && params.postId ? params.postId : '';
    if (this.postId === '') {
      this.loading = false;
      this.errorText = '缺少帖子 ID';
      return;
    }
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    try {
      const raw = await PostApi.fetchPostFull(this.postId);
      const d = PostModels.parseDetail(raw, this.postId);
      if (d.retcode === 0) {
        this.detail = d;
        this.loadReplies(false);
      } else {
        if (d.message.indexOf('升级') >= 0) {
          this.errorText = '该帖子为新版格式，暂不支持在米柚中查看，请使用官方 App 打开';
        } else {
          this.errorText = `接口返回 ${d.retcode}（${d.message}）`;
        }
      }
    } catch (e) {
      this.errorText = '网络异常，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  private async loadReplies(more: boolean): Promise<void> {
    if (this.replyLoading) {
      return;
    }
    this.replyLoading = true;
    if (!more) {
      this.replyError = '';
    }
    try {
      const raw = await PostApi.fetchReplies(this.postId, more ? this.replyLastId : '', 20);
      const r = ReplyModels.parse(raw);
      if (r.retcode === 0) {
        this.replyLastId = r.lastId;
        this.replyIsLast = r.isLast;
        if (more) {
          const merged = this.replies.slice();
          const seen = new Set<string>();
          merged.forEach((x: ReplyItem) => seen.add(x.replyId));
          r.replies.forEach((x: ReplyItem) => {
            if (!seen.has(x.replyId)) {
              seen.add(x.replyId);
              merged.push(x);
            }
          });
          this.replies = merged;
        } else {
          this.replies = r.replies;
        }
        this.replyLoaded = true;
        this.replyError = '';
      } else {
        this.replyError = `评论接口返回 ${r.retcode}（${r.message}）`;
      }
    } catch (e) {
      this.replyError = '评论加载失败，请检查网络';
    } finally {
      this.replyLoading = false;
    }
  }

  private floorIdOf(replyId: string): number {
    const n = Number(replyId);
    return isNaN(n) ? 0 : n;
  }

  private updateFloor(replyId: string, mutate: (state: SubFloorState) => SubFloorState): void {
    const next = new Map<string, SubFloorState>(this.floorStates);
    const cur = next.get(replyId) ?? emptyFloorState();
    next.set(replyId, mutate(cur));
    this.floorStates = next;
  }

  private async toggleFloor(reply: ReplyItem, expanded: boolean): Promise<void> {
    this.updateFloor(reply.replyId, (s: SubFloorState) => {
      s.expanded = expanded;
      if (expanded && !s.loaded) {
        s.loading = true;
      }
      return s;
    });
    if (!expanded) {
      return;
    }
    await this.loadSubReplies(reply, false);
  }

  private async loadSubReplies(reply: ReplyItem, more: boolean): Promise<void> {
    const floorId = this.floorIdOf(reply.replyId);
    if (floorId <= 0) {
      this.updateFloor(reply.replyId, (s: SubFloorState) => {
        s.loading = false;
        s.errorText = '楼层 ID 无效，无法展开';
        return s;
      });
      return;
    }
    const cur = this.floorStates.get(reply.replyId) ?? emptyFloorState();
    const lastId = more ? cur.lastId : '';
    try {
      const raw = await PostApi.fetchSubReplies(this.postId, floorId, 2, lastId, 20);
      const r = ReplyModels.parse(raw);
      this.updateFloor(reply.replyId, (s: SubFloorState) => {
        s.loading = false;
        s.loaded = true;
        if (r.retcode === 0) {
          s.errorText = '';
          s.lastId = r.lastId;
          s.isLast = r.isLast;
          if (more) {
            const merged = s.replies.slice();
            const seen = new Set<string>();
            merged.forEach((x: ReplyItem) => seen.add(x.replyId));
            r.replies.forEach((x: ReplyItem) => {
              if (!seen.has(x.replyId)) {
                seen.add(x.replyId);
                merged.push(x);
              }
            });
            s.replies = merged;
          } else {
            s.replies = r.replies;
          }
        } else {
          s.errorText = `子回复接口返回 ${r.retcode}（${r.message}）`;
        }
        return s;
      });
    } catch (e) {
      this.updateFloor(reply.replyId, (s: SubFloorState) => {
        s.loading = false;
        s.errorText = '子回复加载失败，请检查网络';
        return s;
      });
    }
  }

  @Builder
  BlockView(block: PostBlock) {
    if (block.kind === 'text') {
      Text(block.text)
        .fontSize(15)
        .fontColor('#101828')
        .lineHeight(24)
        .width('100%')
    } else if (block.kind === 'image') {
      Image(block.imageUrl)
        .width('100%')
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
        .constraintSize({ maxHeight: 420 })
        .onClick(() => {
          this.previewUrl = block.imageUrl;
          this.showPreview = true;
        })
    } else {
      Column() {
        Text('此内容块暂不支持展示')
          .fontSize(12)
          .fontColor('#98A2B3')
      }
      .width('100%')
      .padding(10)
      .backgroundColor('#F2F4F7')
      .borderRadius(8)
    }
  }

  @Builder
  TopBar() {
    Row({ space: 12 }) {
      Text('←').fontSize(22).fontColor('#101828')
        .onClick(() => router.back())
      Text('帖子')
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
  ReplyView(item: ReplyItem, isSub: boolean) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Image(item.avatar)
          .width(32)
          .height(32)
          .borderRadius(16)
          .alt($r('app.media.app_icon'))
          .onClick(() => {
            if (item.authorUid !== '') {
              router.pushUrl({ url: 'pages/UserProfile', params: { uid: item.authorUid } });
            }
          })
        Column({ space: 2 }) {
          Text(item.author)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#344054')
            .onClick(() => {
              if (item.authorUid !== '') {
                router.pushUrl({ url: 'pages/UserProfile', params: { uid: item.authorUid } });
              }
            })
          Text(item.timeText)
            .fontSize(11)
            .fontColor('#98A2B3')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (item.likeNum > 0) {
          Text(`赞 ${formatCount(item.likeNum)}`)
            .fontSize(11)
            .fontColor('#98A2B3')
        }
      }
      .width('100%')
      if (item.content !== '') {
        Text(item.content)
          .fontSize(14)
          .fontColor('#101828')
          .lineHeight(21)
          .width('100%')
      }
      if (item.images.length > 0) {
        ForEach(item.images, (imgUrl: string) => {
          Image(imgUrl)
            .width('100%')
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
            .constraintSize({ maxHeight: 300 })
            .margin({ top: 6 })
            .onClick(() => {
              this.previewUrl = imgUrl;
              this.showPreview = true;
            })
        })
      }
      if (!isSub && item.subReplyCount > 0) {
        Text(`共 ${item.subReplyCount} 条回复 ›`)
          .fontSize(12)
          .fontColor('#1570EF')
          .onClick(() => {
            this.toggleFloor(item, !this.floorStateOf(item.replyId).expanded);
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SubFloorPanel(floor: ReplyItem) {
    if (this.isFloorExpanded(floor.replyId)) {
      Divider()
        .width(2)
        .color('#2B1570EF')
        .margin({ left: 8 })
      Column({ space: 8 }) {
        if (this.floorStateOf(floor.replyId).loading && this.floorStateOf(floor.replyId).replies.length === 0) {
          Text('加载中…')
            .fontSize(12)
            .fontColor('#98A2B3')
            .padding({ left: 20 })
        } else if (this.floorStateOf(floor.replyId).errorText !== '') {
          Text(this.floorStateOf(floor.replyId).errorText)
            .fontSize(12)
            .fontColor('#667085')
            .padding({ left: 20 })
          Button('重试')
            .fontSize(12)
            .onClick(() => this.loadSubReplies(floor, false))
        } else if (this.floorStateOf(floor.replyId).replies.length === 0 && this.floorStateOf(floor.replyId).loaded) {
          Text('子回复为空')
            .fontSize(12)
            .fontColor('#98A2B3')
            .padding({ left: 20 })
        } else {
          ForEach(this.floorStateOf(floor.replyId).replies, (subItem: ReplyItem) => {
            Column({ space: 6 }) {
              this.ReplyView(subItem, true)
            }
            .width('100%')
            .padding({ left: 20 })
          }, (subItem: ReplyItem) => subItem.replyId)
          if (!this.floorStateOf(floor.replyId).isLast) {
            Button(this.floorStateOf(floor.replyId).loading ? '加载中…' : '加载更多子回复')
              .fontSize(12)
              .enabled(!this.floorStateOf(floor.replyId).loading)
              .onClick(() => this.loadSubReplies(floor, true))
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 4 })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F8FA')

      Column() {
        if (this.loading) {
          Column() {
            Text('加载中…').fontSize(14).fontColor('#98A2B3')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.errorText !== '') {
          Column({ space: 12 }) {
            Text(this.errorText).fontSize(14).fontColor('#667085')
            Button('重试').onClick(() => this.load())
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.detail !== null) {
          Scroll() {
            Column({ space: 14 }) {
              // 作者卡（可点击进入用户主页）
              Row({ space: 10 }) {
                Image(this.detail!.avatar)
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .alt($r('app.media.app_icon'))
                Column({ space: 2 }) {
                  Row({ space: 6 }) {
                    Text(this.detail!.author)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#101828')
                    if (this.detail!.isOfficial) {
                      Text('官')
                        .fontSize(10)
                        .fontColor('#1570EF')
                        .backgroundColor('#E5F6FF')
                        .borderRadius(4)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                    }
                  }
                  Text(this.detail!.timeText + (this.detail!.forumName !== '' ? ' · ' + this.detail!.forumName : ''))
                    .fontSize(12)
                    .fontColor('#98A2B3')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text('›')
                  .fontSize(20)
                  .fontColor('#C0C4CC')
              }
              .width('100%')
              .onClick(() => {
                if (this.detail!.authorUid !== '') {
                  router.pushUrl({ url: 'pages/UserProfile', params: { uid: this.detail!.authorUid } });
                }
              })

              // 标题
              if (this.detail!.title !== '') {
                Text(this.detail!.title)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#101828')
                  .width('100%')
                  .lineHeight(28)
              }

              // 正文块
              ForEach(this.detail!.blocks, (b: PostBlock) => {
                this.BlockView(b)
              })

              // 话题
              if (this.detail!.topics.length > 0) {
                Row({ space: 8 }) {
                  ForEach(this.detail!.topics, (t: string) => {
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

              // 互动行（只读）
              Row({ space: 24 }) {
                Text(`浏览 ${formatCount(this.detail!.viewNum)}`).fontSize(13).fontColor('#98A2B3')
                Text(`评论 ${formatCount(this.detail!.replyNum)}`).fontSize(13).fontColor('#98A2B3')
                Text(`点赞 ${formatCount(this.detail!.likeNum)}`).fontSize(13).fontColor('#98A2B3')
                Blank()
                Text('只读').fontSize(11).fontColor('#C0C4CC')
              }
              .width('100%')
              .padding({ top: 4, bottom: 8 })

              // 评论区
              Column({ space: 12 }) {
                Text('评论')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#101828')
                  .width('100%')
                if (this.replies.length === 0 && this.replyLoading) {
                  Text('评论加载中…')
                    .fontSize(13)
                    .fontColor('#98A2B3')
                    .width('100%')
                } else if (this.replies.length === 0 && this.replyError !== '') {
                  Text(this.replyError)
                    .fontSize(13)
                    .fontColor('#667085')
                    .width('100%')
                  Button('重试')
                    .onClick(() => this.loadReplies(false))
                } else if (this.replies.length === 0 && this.replyLoaded) {
                  Text('还没有评论')
                    .fontSize(13)
                    .fontColor('#98A2B3')
                    .width('100%')
                } else {
                  ForEach(this.replies, (item: ReplyItem) => {
                    Column({ space: 8 }) {
                      this.ReplyView(item, false)
                      this.SubFloorPanel(item)
                    }
                    .width('100%')
                  }, (item: ReplyItem) => item.replyId)
                  if (!this.replyIsLast) {
                    Button(this.replyLoading ? '加载中…' : '加载更多评论')
                      .enabled(!this.replyLoading)
                      .onClick(() => this.loadReplies(true))
                  }
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 8, bottom: 20 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 20 + this.vp(this.safeBottomPx) })
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: 56 + this.vp(this.safeTopPx) })

      this.TopBar()

      // 图片全屏预览
      if (this.showPreview && this.previewUrl !== '') {
        Column() {
          Image(this.previewUrl)
            .width('100%')
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showPreview = false;
          this.previewUrl = '';
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
