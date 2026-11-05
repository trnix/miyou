import { common } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { MysHttp } from '../net/MysHttp';
import { TextRun, linkRuns, webUrl } from '../model/PostContentModels';

export async function openPostLink(ctx: common.UIAbilityContext, target: string): Promise<void> {
  const uri = webUrl(target);
  if (uri === '') { throw new Error('仅支持 HTTP(S) 网页链接'); }
  await ctx.startAbility({ action: 'ohos.want.action.viewData', entities: ['entity.system.browsable'], uri });
}

@Component
export struct PostText {
  @Prop text: string = '';
  @Prop runs: TextRun[] = [];
  @Prop textSize: number = 15;
  @Prop textLine: number = 24;

  private parts(): TextRun[] { return this.runs.length > 0 ? this.runs : linkRuns(this.text); }
  private open(url: string): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    openPostLink(ctx, url).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '无法打开浏览器，请检查默认浏览器设置' });
    });
  }

  build() {
    Text() {
      ForEach(this.parts(), (part: TextRun) => {
        if (part.url !== '') {
          Span(part.text).fontColor('#1570EF').decoration({ type: TextDecorationType.Underline })
            .onClick(() => this.open(part.url))
        } else { Span(part.text) }
      })
    }.fontSize(this.textSize).fontColor('#101828').lineHeight(this.textLine).width('100%')
      .copyOption(CopyOptions.LocalDevice).textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
  }
}

@Component
export struct PostVideo {
  @Prop source: string = '';
  @Prop cover: string = '';
  @State started: boolean = false;
  @State failed: boolean = false;
  private controller: VideoController = new VideoController();

  aboutToDisappear(): void { try { this.controller.pause(); } catch (e) {} }

  build() {
    Column({ space: 8 }) {
      if (this.source === '') {
        Text('此视频暂未提供可播放地址').fontSize(13).fontColor('#667085').padding(24)
      } else if (this.failed) {
        Text('视频播放失败，可能是网络异常或地址已过期').fontSize(13).fontColor('#667085').padding(12)
        Button('重试').onClick(() => { this.failed = false; })
      } else if (this.started) {
        Video({ src: this.source, previewUri: this.cover, controller: this.controller })
          .width('100%').aspectRatio(16 / 9).controls(true).autoPlay(true).objectFit(ImageFit.Contain)
          .onError(() => { this.failed = true; })
          .onVisibleAreaChange([0.0, 0.1], (visible: boolean) => {
            if (!visible) { try { this.controller.pause(); } catch (e) {} }
          })
      } else {
        Stack() {
          if (this.cover !== '') { Image(this.cover).width('100%').height('100%').objectFit(ImageFit.Cover) }
          Text('▶ 播放视频').fontSize(16).fontColor('#FFFFFF').padding(14).backgroundColor('#99000000').borderRadius(24)
        }.width('100%').aspectRatio(16 / 9).backgroundColor('#101828')
          .onClick(() => { this.started = true; })
      }
    }.width('100%').backgroundColor('#F2F4F7').borderRadius(10).clip(true)
  }
}

interface CachedImage { path: string; uri: string; ext: string; }

class ImageFiles {
  private static busy: boolean = false;
  private static serial: number = 0;

  private static extension(data: ArrayBuffer): string {
    const b = new Uint8Array(data);
    if (b.length >= 4 && b[0] === 137 && b[1] === 80 && b[2] === 78 && b[3] === 71) { return 'png'; }
    if (b.length >= 3 && b[0] === 255 && b[1] === 216 && b[2] === 255) { return 'jpg'; }
    if (b.length >= 6 && b[0] === 71 && b[1] === 73 && b[2] === 70 && b[3] === 56) { return 'gif'; }
    if (b.length >= 12 && b[0] === 82 && b[1] === 73 && b[8] === 87 && b[9] === 69 && b[10] === 66 && b[11] === 80) { return 'webp'; }
    throw new Error('暂不支持保存或分享此图片格式');
  }

  private static remove(path: string): void { try { fs.unlinkSync(path); } catch (e) {} }

  private static cleanup(ctx: common.UIAbilityContext): void {
    try {
      fs.listFileSync(ctx.cacheDir).forEach((name: string) => {
        const match = /^miyou_post_(\d+)_\d+\.(jpg|png|gif|webp)$/.exec(name);
        if (match !== null && Date.now() - Number(match[1]) > 48 * 3600000) {
          ImageFiles.remove(ctx.cacheDir + '/' + name);
        }
      });
    } catch (e) {}
  }

  private static async cache(ctx: common.UIAbilityContext, url: string): Promise<CachedImage> {
    ImageFiles.cleanup(ctx);
    const data = await MysHttp.imageBytes(url);
    const ext = ImageFiles.extension(data);
    const path = `${ctx.cacheDir}/miyou_post_${Date.now()}_${++ImageFiles.serial}.${ext}`;
    const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try {
      const written = await fs.write(file.fd, data);
      if (written !== data.byteLength) { throw new Error('图片缓存写入不完整'); }
    } catch (e) {
      ImageFiles.remove(path);
      throw new Error('图片缓存失败');
    } finally { await fs.close(file); }
    return { path, uri: fileUri.getUriFromPath(path), ext };
  }

  private static async save(ctx: common.UIAbilityContext, item: CachedImage): Promise<boolean> {
    const helper = photoAccessHelper.getPhotoAccessHelper(ctx);
    try {
      const configs: photoAccessHelper.PhotoCreationConfig[] = [{
        title: 'MiYou_' + Date.now(), fileNameExtension: item.ext, photoType: photoAccessHelper.PhotoType.IMAGE
      }];
      const targets = await helper.showAssetsCreationDialog([item.uri], configs);
      if (targets.length === 0) { return false; }
      const source = await fs.open(item.uri, fs.OpenMode.READ_ONLY);
      try {
        const dest = await fs.open(targets[0], fs.OpenMode.WRITE_ONLY);
        try { await fs.copyFile(source.fd, dest.fd); } finally { await fs.close(dest); }
      } finally { await fs.close(source); }
      return true;
    } finally { await helper.release(); }
  }

  static async perform(ctx: common.UIAbilityContext, ui: UIContext, url: string, share: boolean): Promise<void> {
    if (ImageFiles.busy) { ui.getPromptAction().showToast({ message: '图片处理中，请稍候' }); return; }
    ImageFiles.busy = true;
    let cached: CachedImage | null = null;
    let retain = false;
    try {
      ui.getPromptAction().showToast({ message: '正在准备图片…' });
      cached = await ImageFiles.cache(ctx, url);
      if (share) {
        const data = new systemShare.SharedData({ utd: utd.UniformDataType.IMAGE, uri: cached.uri });
        const controller = new systemShare.ShareController(data);
        await controller.show(ctx, { selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DETAIL });
        retain = true; // 分享接收方可能延后读取；48小时后下次操作清理，不在面板关闭时立刻删。
      } else if (await ImageFiles.save(ctx, cached)) {
        ui.getPromptAction().showToast({ message: '已保存到系统图库' });
      }
    } catch (e) {
      ui.getPromptAction().showToast({ message: '图片操作失败，请检查网络、图片格式或系统授权后重试' });
    } finally {
      if (cached !== null && !retain) { ImageFiles.remove(cached.path); }
      ImageFiles.busy = false;
    }
  }
}

@CustomDialog
export struct ImageActionsDialog {
  controller?: CustomDialogController;
  imageUrl: string = '';

  private run(share: boolean): void {
    const ui = this.getUIContext();
    const ctx = ui.getHostContext() as common.UIAbilityContext;
    const url = this.imageUrl;
    this.controller?.close();
    ImageFiles.perform(ctx, ui, url, share);
  }

  build() {
    Column({ space: 4 }) {
      Text('图片操作').fontSize(17).fontWeight(FontWeight.Medium).padding(16)
      Button('分享图片').width('100%').height(48).backgroundColor('#F2F4F7').fontColor('#1570EF').onClick(() => this.run(true))
      Button('保存到图库').width('100%').height(48).backgroundColor('#F2F4F7').fontColor('#101828').onClick(() => this.run(false))
      Button('取消').width('100%').height(48).backgroundColor('#FFFFFF').fontColor('#667085').onClick(() => this.controller?.close())
    }.width('85%').constraintSize({ maxWidth: 360 }).padding(16).backgroundColor('#FFFFFF').borderRadius(20)
  }
}
