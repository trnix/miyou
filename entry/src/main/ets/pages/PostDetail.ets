import { router } from '@kit.ArkUI';
import { PostApi } from '../net/PostApi';
import { PostModels, PostDetail, PostBlock } from '../model/PostModels';
import { ReplyModels, ReplyItem } from '../model/ReplyModels';
import { GlassTheme } from '../view/GlassTheme';
import { formatCount } from '../model/FeedModels';

interface RouteParams {
  postId?: string;
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
  private postId: string = '';

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
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
        this.errorText = `接口返回 ${d.retcode}（${d.message}）`;
      }
    } catch (e) {
      this.errorText = '网络异常，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  // 评论独立异步加载，不阻塞正文；more=true 时按 last_id 游标翻页并去重合并。
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
  ReplyView(item: ReplyItem) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Image(item.avatar)
          .width(32)
          .height(32)
          .borderRadius(16)
          .alt($r('app.media.app_icon'))
        Column({ space: 2 }) {
          Text(item.author)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#344054')
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
      if (item.subReplyCount > 0) {
        Text(`共 ${item.subReplyCount} 条回复`)
          .fontSize(12)
          .fontColor('#1570EF')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
              // 作者卡
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
              }
              .width('100%')

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
                    this.ReplyView(item)
                  }, (item: ReplyItem) => item.replyId)
                  if (!this.replyIsLast) {
                    Button(this.replyLoading ? '加载中…' : '加载更多评论')
                      .enabled(!this.replyLoading)
                      .onClick(() => this.loadReplies(true))
                  } else {
                    Text('楼中楼回复将在 R6 接入')
                      .fontSize(11)
                      .fontColor('#C0C4CC')
                      .width('100%')
                      .textAlign(TextAlign.Center)
                  }
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding({ top: 8, bottom: 20 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16 })
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: 56 + this.vp(this.safeTopPx), bottom: this.vp(this.safeBottomPx) })

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
