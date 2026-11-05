import { router, window } from '@kit.ArkUI';
import { PostApi } from '../net/PostApi';
import { PostContentModels as PostModels, RichPostDetail as PostDetail, ContentBlock as PostBlock } from '../model/PostContentModels';
import { ReplyModels, ReplyItem } from '../model/ReplyModels';
import { GlassTheme } from '../view/GlassTheme';
import { AdaptiveImage, ThumbRect } from '../view/AdaptiveImage';
import { PostText, PostVideo, ImageActionsDialog } from '../view/PostInteractions';
import { formatCount } from '../model/FeedModels';

interface RouteParams { postId?: string; }
interface SubFloorState {
  expanded: boolean; loading: boolean; loaded: boolean; replies: ReplyItem[];
  lastId: string; isLast: boolean; errorText: string;
}
function emptyFloorState(): SubFloorState {
  return { expanded: false, loading: false, loaded: false, replies: [], lastId: '', isLast: true, errorText: '' };
}
interface FitRect { x: number; y: number; w: number; h: number; }
interface PreviewImageInfo { width: number; height: number; }

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
  @State previewScale: number = 1;
  private previewBaseScale: number = 1;
  @State boxX: number = 0;
  @State boxY: number = 0;
  @State boxW: number = 0;
  @State boxH: number = 0;
  @State boxRadius: number = 0;
  @State scrimAlpha: number = 0;
  @State flyingAlpha: number = 0;
  private lastThumbX: number = 0;
  private lastThumbY: number = 0;
  private lastThumbW: number = 0;
  private lastThumbH: number = 0;
  private lastThumbR: number = 0;
  private winW: number = 0;
  private winH: number = 0;
  private previewSeq: number = 0;
  @State actionImageUrl: string = '';
  private imageMenu: CustomDialogController = new CustomDialogController({
    builder: ImageActionsDialog({ imageUrl: this.actionImageUrl }),
    alignment: DialogAlignment.Center, autoCancel: true, customStyle: true
  });
  @State replies: ReplyItem[] = [];
  @State replyLoading: boolean = false;
  @State replyError: string = '';
  @State replyLastId: string = '';
  @State replyIsLast: boolean = true;
  @State replyLoaded: boolean = false;
  @State floorStates: Map<string, SubFloorState> = new Map<string, SubFloorState>();
  private postId: string = '';

  private vp(px: number): number { return this.getUIContext().px2vp(px); }
  private openImageMenu(url: string): void {
    if (url === '') { return; }
    this.actionImageUrl = url;
    this.imageMenu.open();
  }

  private fitRectFor(imgAspect: number): FitRect {
    if (this.winW <= 0 || this.winH <= 0 || imgAspect <= 0) {
      return { x: this.lastThumbX, y: this.lastThumbY, w: this.lastThumbW, h: this.lastThumbH };
    }
    const screenAspect = this.winW / this.winH;
    if (imgAspect >= screenAspect) {
      const h = this.winW / imgAspect;
      return { x: 0, y: (this.winH - h) / 2, w: this.winW, h };
    }
    const w = this.winH * imgAspect;
    return { x: (this.winW - w) / 2, y: 0, w, h: this.winH };
  }

  // V5.1 飞行路径、时长和透明度时序保持已验收方案。
  private openPreview(url: string, rect: ThumbRect): void {
    const seq = ++this.previewSeq;
    this.previewUrl = url;
    this.previewScale = 1;
    this.previewBaseScale = 1;
    this.lastThumbX = rect.x; this.lastThumbY = rect.y;
    this.lastThumbW = rect.w; this.lastThumbH = rect.h; this.lastThumbR = rect.r;
    const imgAspect = rect.iw > 0 && rect.ih > 0 ? rect.iw / rect.ih : (rect.h > 0 ? rect.w / rect.h : 1);
    const fit = this.fitRectFor(imgAspect);
    this.boxX = rect.x; this.boxY = rect.y; this.boxW = rect.w; this.boxH = rect.h; this.boxRadius = rect.r;
    this.scrimAlpha = 0; this.flyingAlpha = 0; this.showPreview = true;
    setTimeout(() => {
      if (seq !== this.previewSeq) { return; }
      if (this.flyingAlpha === 0) { this.flyingAlpha = 1; }
    }, 500);
    setTimeout(() => {
      if (seq !== this.previewSeq) { return; }
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.boxX = fit.x; this.boxY = fit.y; this.boxW = fit.w; this.boxH = fit.h;
        this.boxRadius = 0; this.scrimAlpha = 1;
      });
    }, 30);
  }

  private closePreview(): void {
    const seq = ++this.previewSeq;
    const needUnzoom = this.previewScale > 1.01;
    if (needUnzoom) {
      animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.previewScale = 1; this.previewBaseScale = 1; });
    }
    const flyDelay = needUnzoom ? 200 : 30;
    setTimeout(() => {
      if (seq !== this.previewSeq) { return; }
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.boxX = this.lastThumbX; this.boxY = this.lastThumbY;
        this.boxW = this.lastThumbW; this.boxH = this.lastThumbH;
        this.boxRadius = this.lastThumbR; this.scrimAlpha = 0;
      });
    }, flyDelay);
    setTimeout(() => {
      if (seq !== this.previewSeq) { return; }
      this.showPreview = false; this.previewUrl = ''; this.previewScale = 1;
      this.previewBaseScale = 1; this.flyingAlpha = 0;
    }, flyDelay + 250);
  }

  onBackPress(): boolean {
    if (this.showPreview) { this.closePreview(); return true; }
    return false;
  }

  private floorStateOf(id: string): SubFloorState { return this.floorStates.get(id) ?? emptyFloorState(); }
  private isFloorExpanded(id: string): boolean { return this.floorStateOf(id).expanded; }

  aboutToAppear(): void {
    const params = router.getParams() as RouteParams | undefined;
    this.postId = params && params.postId ? params.postId : '';
    if (this.postId === '') { this.loading = false; this.errorText = '缺少帖子 ID'; return; }
    window.getLastWindow(getContext(this)).then((win: window.Window) => {
      const props = win.getWindowProperties();
      const ctx = this.getUIContext();
      this.winW = ctx.px2vp(props.windowRect.width); this.winH = ctx.px2vp(props.windowRect.height);
    }).catch(() => { this.winW = 0; this.winH = 0; });
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true; this.errorText = '';
    try {
      const raw = await PostApi.fetchPostFull(this.postId);
      const d = PostModels.parseDetail(raw, this.postId);
      if (d.retcode === 0) { this.detail = d; this.loadReplies(false); }
      else {
        this.errorText = d.message.indexOf('升级') >= 0 ? '该帖子为新版格式，暂不支持在米柚中查看，请使用官方 App 打开'
          : `接口返回 ${d.retcode}（${d.message}）`;
      }
    } catch (e) { this.errorText = '网络异常，请检查网络后重试'; }
    finally { this.loading = false; }
  }

  private async loadReplies(more: boolean): Promise<void> {
    if (this.replyLoading) { return; }
    this.replyLoading = true;
    if (!more) { this.replyError = ''; }
    try {
      const raw = await PostApi.fetchReplies(this.postId, more ? this.replyLastId : '', 20);
      const r = ReplyModels.parse(raw);
      if (r.retcode === 0) {
        this.replyLastId = r.lastId; this.replyIsLast = r.isLast;
        if (more) {
          const merged = this.replies.slice();
          const seen = new Set<string>();
          merged.forEach((x: ReplyItem) => seen.add(x.replyId));
          r.replies.forEach((x: ReplyItem) => { if (!seen.has(x.replyId)) { seen.add(x.replyId); merged.push(x); } });
          this.replies = merged;
        } else { this.replies = r.replies; }
        this.replyLoaded = true; this.replyError = '';
      } else { this.replyError = `评论接口返回 ${r.retcode}（${r.message}）`; }
    } catch (e) { this.replyError = '评论加载失败，请检查网络'; }
    finally { this.replyLoading = false; }
  }

  private updateFloor(id: string, mutate: (state: SubFloorState) => SubFloorState): void {
    const next = new Map<string, SubFloorState>(this.floorStates);
    next.set(id, mutate(next.get(id) ?? emptyFloorState()));
    this.floorStates = next;
  }

  private async toggleFloor(reply: ReplyItem, expanded: boolean): Promise<void> {
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.updateFloor(reply.replyId, (s: SubFloorState) => { s.expanded = expanded; return s; });
    });
    if (expanded && !this.floorStateOf(reply.replyId).loaded) { await this.loadSubReplies(reply, false); }
  }

  private async loadSubReplies(reply: ReplyItem, more: boolean): Promise<void> {
    const floorId = Number(reply.replyId);
    if (!Number.isFinite(floorId) || floorId <= 0) {
      this.updateFloor(reply.replyId, (s: SubFloorState) => { s.loading = false; s.errorText = '楼层 ID 无效，无法展开'; return s; });
      return;
    }
    const cur = this.floorStateOf(reply.replyId);
    if (cur.loading) { return; }
    const lastId = more ? cur.lastId : '';
    this.updateFloor(reply.replyId, (s: SubFloorState) => { s.loading = true; s.errorText = ''; return s; });
    try {
      const raw = await PostApi.fetchSubReplies(this.postId, floorId, 2, lastId, 20);
      const r = ReplyModels.parse(raw);
      this.updateFloor(reply.replyId, (s: SubFloorState) => {
        s.loading = false;
        if (r.retcode === 0) {
          s.loaded = true; s.errorText = ''; s.lastId = r.lastId; s.isLast = r.isLast;
          if (more) {
            const merged = s.replies.slice();
            const seen = new Set<string>();
            merged.forEach((x: ReplyItem) => seen.add(x.replyId));
            r.replies.forEach((x: ReplyItem) => { if (!seen.has(x.replyId)) { seen.add(x.replyId); merged.push(x); } });
            s.replies = merged;
          } else { s.replies = r.replies; }
        } else { s.errorText = `子回复接口返回 ${r.retcode}（${r.message}）`; }
        return s;
      });
    } catch (e) {
      this.updateFloor(reply.replyId, (s: SubFloorState) => { s.loading = false; s.errorText = '子回复加载失败，请检查网络'; return s; });
    }
  }

  @Builder
  BlockView(block: PostBlock) {
    if (block.kind === 'text') {
      PostText({ text: block.text, runs: block.runs })
    } else if (block.kind === 'image') {
      AdaptiveImage({ imageUrl: block.imageUrl, radius: 10,
        onTap: (rect: ThumbRect) => this.openPreview(block.imageUrl, rect),
        onLongPress: () => this.openImageMenu(block.imageUrl) })
    } else if (block.kind === 'video') {
      PostVideo({ source: block.videoUrl, cover: block.imageUrl })
    } else {
      Text('此内容块暂不支持展示').fontSize(12).fontColor('#98A2B3').width('100%')
        .padding(10).backgroundColor('#F2F4F7').borderRadius(8)
    }
  }

  @Builder
  TopBar() {
    Row({ space: 12 }) {
      Text('←').fontSize(22).fontColor('#101828').onClick(() => router.back())
      Text('帖子').fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
      Text('').width(22)
    }.width('100%').height(56 + this.vp(this.safeTopPx))
      .padding({ top: this.vp(this.safeTopPx), left: 16, right: 16 })
      .backgroundColor(GlassTheme.barColor(this.glassLevel)).systemMaterial(GlassTheme.material(this.glassLevel))
      .border({ width: { bottom: 0.5 }, color: GlassTheme.edgeColor(this.glassLevel) })
  }

  @Builder
  ReplyView(item: ReplyItem, isSub: boolean) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Image(item.avatar).width(32).height(32).borderRadius(16).backgroundColor('#F2F4F7').alt($r('app.media.app_icon'))
          .onClick(() => { if (item.authorUid !== '') { router.pushUrl({ url: 'pages/UserProfile', params: { uid: item.authorUid } }); } })
        Column({ space: 2 }) {
          Text(item.author).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#344054')
            .onClick(() => { if (item.authorUid !== '') { router.pushUrl({ url: 'pages/UserProfile', params: { uid: item.authorUid } }); } })
          Text(item.timeText).fontSize(11).fontColor('#98A2B3')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        if (item.likeNum > 0) { Text(`赞 ${formatCount(item.likeNum)}`).fontSize(11).fontColor('#98A2B3') }
      }.width('100%')
      if (item.content !== '') { PostText({ text: item.content, size: 14, line: 21 }) }
      if (item.images.length > 0) {
        ForEach(item.images, (url: string) => {
          Column() {
            AdaptiveImage({ imageUrl: url, radius: 8, onTap: (rect: ThumbRect) => this.openPreview(url, rect),
              onLongPress: () => this.openImageMenu(url) })
          }.width('100%').margin({ top: 6 })
        })
      }
      if (!isSub && item.subReplyCount > 0) {
        Text(`共 ${item.subReplyCount} 条回复 ›`).fontSize(12).fontColor('#1570EF')
          .onClick(() => this.toggleFloor(item, !this.floorStateOf(item.replyId).expanded))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  SubFloorPanel(floor: ReplyItem) {
    if (this.isFloorExpanded(floor.replyId)) {
      Column({ space: 8 }) {
        Divider().width(2).color('#2B1570EF').margin({ left: 8 })
        if (this.floorStateOf(floor.replyId).loading && this.floorStateOf(floor.replyId).replies.length === 0) {
          Text('加载中…').fontSize(12).fontColor('#98A2B3').padding({ left: 20 })
        } else if (this.floorStateOf(floor.replyId).errorText !== '') {
          Text(this.floorStateOf(floor.replyId).errorText).fontSize(12).fontColor('#667085').padding({ left: 20 })
          Button('重试').fontSize(12).onClick(() => this.loadSubReplies(floor, false))
        } else if (this.floorStateOf(floor.replyId).replies.length === 0 && this.floorStateOf(floor.replyId).loaded) {
          Text('子回复为空').fontSize(12).fontColor('#98A2B3').padding({ left: 20 })
        } else {
          ForEach(this.floorStateOf(floor.replyId).replies, (item: ReplyItem) => {
            Column({ space: 6 }) { this.ReplyView(item, true) }.width('100%').padding({ left: 20 })
          }, (item: ReplyItem) => item.replyId)
          if (!this.floorStateOf(floor.replyId).isLast) {
            Button(this.floorStateOf(floor.replyId).loading ? '加载中…' : '加载更多子回复').fontSize(12)
              .enabled(!this.floorStateOf(floor.replyId).loading).onClick(() => this.loadSubReplies(floor, true))
          }
        }
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 4 })
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.move(TransitionEdge.TOP))
          .animation({ duration: 200, curve: Curve.EaseOut }))
    }
  }

  @Builder
  PreviewLayer() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#000000').opacity(this.scrimAlpha).onClick(() => this.closePreview())
      Image(this.previewUrl).position({ x: this.boxX, y: this.boxY }).width(this.boxW).height(this.boxH)
        .objectFit(ImageFit.Cover).borderRadius(this.boxRadius).clip(true).backgroundColor('#F2F4F7')
        .opacity(this.flyingAlpha).scale({ x: this.previewScale, y: this.previewScale, z: 1 })
        .onComplete((event?: PreviewImageInfo) => {
          if (event !== undefined && event.width > 0 && event.height > 0 && this.flyingAlpha < 1) {
            animateTo({ duration: 90, curve: Curve.EaseOut }, () => { this.flyingAlpha = 1; });
          }
        })
        .gesture(PinchGesture({ fingers: 2 }).onActionUpdate((event?: GestureEvent) => {
          if (event !== undefined) { this.previewScale = Math.min(6, Math.max(1, this.previewBaseScale * event.scale)); }
        }).onActionEnd(() => { this.previewBaseScale = this.previewScale; }))
        .gesture(TapGesture({ count: 2 }).onAction(() => {
          if (this.previewScale > 1.01) {
            animateTo({ duration: 180, curve: Curve.EaseOut }, () => { this.previewScale = 1; this.previewBaseScale = 1; });
          }
        }))
        .parallelGesture(LongPressGesture({ repeat: false }).onAction(() => this.openImageMenu(this.previewUrl)))
    }.width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column().width('100%').height('100%').backgroundColor('#F7F8FA')
      Column() {
        if (this.loading) {
          Column() { Text('加载中…').fontSize(14).fontColor('#98A2B3') }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.errorText !== '') {
          Column({ space: 12 }) {
            Text(this.errorText).fontSize(14).fontColor('#667085')
            Button('重试').onClick(() => this.load())
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.detail !== null) {
          Scroll() {
            Column({ space: 14 }) {
              Row({ space: 10 }) {
                Image(this.detail!.avatar).width(44).height(44).borderRadius(22).backgroundColor('#F2F4F7').alt($r('app.media.app_icon'))
                Column({ space: 2 }) {
                  Row({ space: 6 }) {
                    Text(this.detail!.author).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#101828')
                    if (this.detail!.isOfficial) {
                      Text('官').fontSize(10).fontColor('#1570EF').backgroundColor('#E5F6FF').borderRadius(4)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                    }
                  }
                  Text(this.detail!.timeText + (this.detail!.forumName !== '' ? ' · ' + this.detail!.forumName : '')).fontSize(12).fontColor('#98A2B3')
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('›').fontSize(20).fontColor('#C0C4CC')
              }.width('100%').onClick(() => {
                if (this.detail!.authorUid !== '') { router.pushUrl({ url: 'pages/UserProfile', params: { uid: this.detail!.authorUid } }); }
              })
              if (this.detail!.title !== '') {
                Text(this.detail!.title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#101828')
                  .width('100%').lineHeight(28).copyOption(CopyOptions.LocalDevice)
                  .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
              }
              ForEach(this.detail!.blocks, (b: PostBlock) => { this.BlockView(b) })
              if (this.detail!.topics.length > 0) {
                Row({ space: 8 }) {
                  ForEach(this.detail!.topics, (t: string) => {
                    Text(t).fontSize(12).fontColor('#475467').backgroundColor('#F2F4F7').borderRadius(10)
                      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  })
                }.width('100%')
              }
              Row({ space: 24 }) {
                Text(`浏览 ${formatCount(this.detail!.viewNum)}`).fontSize(13).fontColor('#98A2B3')
                Text(`评论 ${formatCount(this.detail!.replyNum)}`).fontSize(13).fontColor('#98A2B3')
                Text(`点赞 ${formatCount(this.detail!.likeNum)}`).fontSize(13).fontColor('#98A2B3')
                Blank()
                Text('只读').fontSize(11).fontColor('#C0C4CC')
              }.width('100%').padding({ top: 4, bottom: 8 })
              Column({ space: 12 }) {
                Text('评论').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#101828').width('100%')
                if (this.replies.length === 0 && this.replyLoading) { Text('评论加载中…').fontSize(13).fontColor('#98A2B3').width('100%') }
                else if (this.replies.length === 0 && this.replyError !== '') {
                  Text(this.replyError).fontSize(13).fontColor('#667085').width('100%')
                  Button('重试').onClick(() => this.loadReplies(false))
                } else if (this.replies.length === 0 && this.replyLoaded) { Text('还没有评论').fontSize(13).fontColor('#98A2B3').width('100%') }
                else {
                  ForEach(this.replies, (item: ReplyItem) => {
                    Column({ space: 8 }) { this.ReplyView(item, false); this.SubFloorPanel(item) }.width('100%')
                  }, (item: ReplyItem) => item.replyId)
                  if (!this.replyIsLast) {
                    Button(this.replyLoading ? '加载中…' : '加载更多评论').enabled(!this.replyLoading).onClick(() => this.loadReplies(true))
                  }
                }
              }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 8, bottom: 20 })
            }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 20 + this.vp(this.safeBottomPx) })
          }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        }
      }.width('100%').height('100%').padding({ top: 56 + this.vp(this.safeTopPx) })
      this.TopBar()
      if (this.showPreview && this.previewUrl !== '') { this.PreviewLayer() }
    }.width('100%').height('100%')
  }
}
