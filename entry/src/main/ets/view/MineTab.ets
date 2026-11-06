import { router } from '@kit.ArkUI';
import { bundleManager } from '@kit.AbilityKit';
import { Session } from '../auth/Session';
import { GlassTheme } from './GlassTheme';
import { UserApi } from '../net/UserApi';
import { UserModels, UserProfile } from '../model/UserModels';

@Component
export struct MineTab {
  scroller: Scroller = new Scroller();
  // Tab 保活后 aboutToAppear 只在首次触发；登录态变化通过 @Watch 重置并重拉资料
  @StorageLink('cookie') @Watch('onSessionChange') cookie: string = '';
  @StorageLink('glassLevel') glassLevel: number = 3;
  @State versionName: string = '';
  @State profile: UserProfile | null = null;
  @State loadingProfile: boolean = false;

  aboutToAppear(): void {
    bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
    ).then((info) => {
      this.versionName = info.versionName;
    }).catch(() => {
      this.versionName = '';
    });
    if (Session.loggedIn() && this.profile === null) {
      this.loadProfile();
    }
  }

  onSessionChange(): void {
    this.profile = null;
    if (Session.loggedIn()) {
      this.loadProfile();
    }
  }

  private loadProfile(): void {
    const uid = Session.stuid();
    if (uid === '') {
      return;
    }
    this.loadingProfile = true;
    UserApi.fetchUserFullInfo(uid, '2')
      .then((raw) => {
        const p = UserModels.parseProfile(raw.body);
        if (p.retcode === 0) {
          this.profile = p;
        }
      })
      .catch(() => {
        // 静默失败，不阻塞界面
      })
      .finally(() => {
        this.loadingProfile = false;
      });
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 14 }) {
        if (this.cookie.length === 0) {
          // 未登录：简洁提示 + 去登录
          Column({ space: 10 }) {
            Text('未登录')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
            Text('经米哈游通行证官方网页登录，不接触账密')
              .fontSize(12)
              .fontColor('#667085')
            Button('去登录')
              .onClick(() => router.pushUrl({ url: 'pages/Login' }))
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
        } else {
          // 已登录：头像 + 昵称 + 数据
          Column({ space: 10 }) {
            Row({ space: 12 }) {
              if (this.loadingProfile) {
                Row() {
                  Text('…')
                    .fontSize(24)
                    .fontColor('#98A2B3')
                }
                .width(56)
                .height(56)
                .borderRadius(28)
                .backgroundColor('#F2F4F7')
                .justifyContent(FlexAlign.Center)
              } else if (this.profile !== null && this.profile!.avatar !== '') {
                Image(this.profile!.avatar)
                  .width(56)
                  .height(56)
                  .borderRadius(28)
                  .backgroundColor('#F2F4F7')
                  .alt($r('app.media.app_icon'))
              } else {
                Row() {
                  Text(this.profile !== null && this.profile!.nickname.length > 0
                    ? this.profile!.nickname.substring(0, 1)
                    : '米')
                    .fontSize(22)
                    .fontColor('#7C3AED')
                }
                .width(56)
                .height(56)
                .borderRadius(28)
                .backgroundColor('#E5F6FF')
                .justifyContent(FlexAlign.Center)
              }
              Column({ space: 3 }) {
                Text(this.profile !== null ? this.profile!.nickname : '米游社用户')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#101828')
                Text(`UID ${Session.stuid()}`)
                  .fontSize(12)
                  .fontColor('#98A2B3')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            if (this.profile !== null && this.profile!.introduce !== '') {
              Text(this.profile!.introduce)
                .fontSize(13)
                .fontColor('#667085')
                .width('100%')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }

            if (this.profile !== null) {
              Row({ space: 18 }) {
                Text(`帖子 ${this.profile!.postNum}`).fontSize(12).fontColor('#667085')
                Text(`关注 ${this.profile!.followCnt}`).fontSize(12).fontColor('#667085')
                Text(`粉丝 ${this.profile!.followedCnt}`).fontSize(12).fontColor('#667085')
                Text(`获赞 ${this.profile!.likeNum}`).fontSize(12).fontColor('#667085')
              }
              .width('100%')
            }

            Row({ space: 12 }) {
              Button('退出登录')
                .backgroundColor('#F04438')
                .onClick(() => Session.clear())
              Button('重新登录')
                .onClick(() => router.pushUrl({ url: 'pages/Login' }))
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
        }

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
          Text('顶栏与底栏的沉浸光感材质效果，开关即时生效')
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
    .scrollBar(BarState.Off)
    .clip(false)
  }
}
