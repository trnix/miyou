import { router } from '@kit.ArkUI';
import { bundleManager } from '@kit.AbilityKit';
import { Session } from '../auth/Session';
import { GlassTheme } from './GlassTheme';

@Component
export struct MineTab {
  @StorageLink('cookie') cookie: string = '';
  @StorageLink('glassLevel') glassLevel: number = 3;
  @State versionName: string = '';

  aboutToAppear(): void {
    bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
    ).then((info) => {
      this.versionName = info.versionName;
    }).catch(() => {
      this.versionName = '';
    });
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 10 }) {
          Text(this.cookie.length > 0 ? '已登录' : '未登录')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
          Text(this.cookie.length > 0 ? '会话仅存本机，仅用于查看授权数据' : '经米哈游通行证官方网页登录，不接触账密')
            .fontSize(12)
            .fontColor('#667085')
          Row({ space: 12 }) {
            Button(this.cookie.length > 0 ? '重新登录' : '去登录')
              .onClick(() => router.pushUrl({ url: 'pages/Login' }))
            if (this.cookie.length > 0) {
              Button('退出登录')
                .backgroundColor('#F04438')
                .onClick(() => Session.clear())
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        Column({ space: 10 }) {
          Row() {
            Text('沉浸光感')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.glassLevel > 0 })
              .selectedColor('#1570EF')
              .onChange((isOn: boolean) => {
                GlassTheme.setLevel(isOn ? 3 : 0)
              })
          }
          .width('100%')
          Text('顶栏与底栏的沉浸玻璃拟态效果，开关即时生效')
            .fontSize(12)
            .fontColor('#667085')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        Text(this.versionName !== ''
          ? `米柚 ${this.versionName} · 非官方米游社客户端 · 只读应用`
          : '米柚 · 非官方米游社客户端 · 只读应用')
          .fontSize(11)
          .fontColor('#98A2B3')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 6 })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
  }
}
