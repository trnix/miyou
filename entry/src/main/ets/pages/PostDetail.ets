// 帖子详情页(阶段1只读原型)
import { router } from '@kit.ArkUI';
import { MiyousheApi } from '../net/MiyousheApi';
import { PostImage } from '../model/MiyousheModels';
import { Format } from '../utils/Format';

@Entry
@Component
struct PostDetail {
  @State loading: boolean = true;
  @State error: string = '';
  @State subject: string = '';
  @State nickname: string = '';
  @State avatarUrl: string = '';
  @State textContent: string = '';
  @State images: PostImage[] = [];
  @State viewNum: number = 0;
  @State likeNum: number = 0;
  @State replyNum: number = 0;
  @State createdAt: string = '';
  @State isVideo: boolean = false;
  private postId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined;
    this.postId = params ? params.post_id : '';
    this.load();
  }

  async load(): Promise<void> {
    if (!this.postId) {
      this.error = '缺少帖子 ID';
      this.loading = false;
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const resp = await MiyousheApi.fetchPostFull(this.postId);
      if (resp.retcode !== 0 || !resp.data || !resp.data.post || !resp.data.post.post) {
        const msg = resp.retcode !== 0 ? `接口返回 ${resp.retcode}: ${resp.message}` : '帖子数据为空';
        throw new Error(msg);
      }
      const d = resp.data;
      const post = d.post.post;
      this.subject = post.subject;
      this.textContent = post.content ? Format.stripHtml(post.content) : '';
      this.images = post.images ? post.images : [];
      const user = d.user;
      this.nickname = user && user.nickname ? user.nickname : '未知用户';
      this.avatarUrl = user && user.avatar_url ? user.avatar_url : '';
      const stat = d.stat;
      this.viewNum = stat ? stat.view_num : 0;
      this.likeNum = stat ? stat.like_num : 0;
      this.replyNum = stat ? stat.reply_num : 0;
      this.createdAt = post.created_at ? Format.time(post.created_at) : '';
      // 视频帖:明确提示不支持,不静默丢弃
      this.isVideo = post.view_type === 5 || (d.post.vod_list ? d.post.vod_list.length > 0 : false);
    } catch (e) {
      this.error = `加载失败:${e instanceof Error ? e.message : String(e)}`;
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Button('返回')
          .fontSize(14)
          .height(32)
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .onClick(() => router.back())
        Blank()
        Text('帖子详情')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Blank()
        Row()
          .width(52)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      if (this.error !== '') {
        Column() {
          Text(this.error)
            .fontSize(14)
            .fontColor('#C0392B')
            .textAlign(TextAlign.Center)
          Button('重试')
            .margin({ top: 12 })
            .onClick(() => this.load())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            Text(this.subject)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .width('100%')

            Row() {
              if (this.avatarUrl !== '') {
                Image(this.avatarUrl)
                  .width(28)
                  .height(28)
                  .borderRadius(14)
                  .autoResize(true)
              }
              Text(this.nickname)
                .fontSize(13)
                .fontColor('#666666')
                .margin({ left: 8 })
              Blank()
              Text(this.createdAt)
                .fontSize(12)
                .fontColor('#999999')
            }
            .width('100%')
            .margin({ top: 12 })

            Row() {
              Text(`${Format.num(this.viewNum)} 浏览`)
                .fontSize(12)
                .fontColor('#999999')
              Text(`${Format.num(this.likeNum)} 赞`)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: 12 })
              Text(`${Format.num(this.replyNum)} 评论`)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: 12 })
            }
            .width('100%')
            .margin({ top: 6 })

            if (this.isVideo) {
              Text('视频内容暂不支持播放,当前仅展示图文部分')
                .fontSize(13)
                .fontColor('#B8860B')
                .backgroundColor('#FFF7E0')
                .borderRadius(8)
                .padding(10)
                .width('100%')
                .margin({ top: 12 })
            }

            // 帖子图片(图片帖通常图片在前)
            ForEach(this.images, (img: PostImage) => {
              Image(img.url)
                .width('100%')
                .objectFit(ImageFit.Contain)
                .borderRadius(8)
                .margin({ top: 12 })
            }, (img: PostImage) => img.url)

            // 正文纯文本
            if (this.textContent !== '') {
              Text(this.textContent)
                .fontSize(15)
                .lineHeight(24)
                .fontColor('#333333')
                .width('100%')
                .margin({ top: 12 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.TopStart)
      }
    }
    .width('100%')
    .height('100%')
  }
}
