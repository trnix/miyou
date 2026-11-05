import { router } from '@kit.ArkUI';
import { GAMES, GameInfo, GameTheme, gameByGids, defaultOrder, cleanOrder } from '../net/GameCatalog';
import { GlassTheme } from '../view/GlassTheme';

interface ChannelParams { target?: string; }

@Entry
@Component
struct ChannelManagePage {
  @StorageLink('glassLevel') glassLevel: number = 3;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State target: string = 'home';
  @State mine: number[] = [];
  @State dirty: boolean = false;
  @State saving: boolean = false;
  @State errorText: string = '';

  private vp(px: number): number { return this.getUIContext().px2vp(px); }

  aboutToAppear(): void {
    const params = router.getParams() as ChannelParams | undefined;
    this.target = params && params.target === 'search' ? 'search' : 'home';
    const key = this.target === 'search' ? 'searchChannelOrder' : 'homeChannelOrder';
    const saved = AppStorage.get<number[]>(key);
    this.mine = cleanOrder(saved === undefined ? defaultOrder() : saved);
  }

  private recommended(): GameInfo[] {
    return GAMES.filter((g: GameInfo) => this.mine.indexOf(g.gids) < 0);
  }

  private move(id: number, delta: number): void {
    if (this.saving) { return; }
    const from = this.mine.indexOf(id);
    const to = from + delta;
    if (from < 0 || to < 0 || to >= this.mine.length) { return; }
    const next = this.mine.slice();
    next[from] = next[to];
    next[to] = id;
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.mine = next; });
    this.dirty = true;
  }

  private remove(id: number): void {
    if (this.saving || id === 5 || this.mine.length <= 1) { return; }
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.mine = this.mine.filter((value: number) => value !== id);
    });
    this.dirty = true;
  }

  private add(id: number): void {
    if (this.saving || this.mine.indexOf(id) >= 0) { return; }
    animateTo({ duration: 200, curve: Curve.EaseOut }, () => { this.mine = this.mine.concat([id]); });
    this.dirty = true;
  }

  private async commit(): Promise<void> {
    if (this.saving || !this.dirty) { return; }
    this.saving = true;
    this.errorText = '';
    try {
      await GameTheme.save(this.target, this.mine.slice());
      router.back();
    } catch (e) {
      this.errorText = '频道设置保存失败，请重试';
    } finally { this.saving = false; }
  }

  onBackPress(): boolean { return this.saving; }

  @Builder
  ChannelRow(id: number, selected: boolean, index: number) {
    Row({ space: 12 }) {
      Text(gameByGids(id).short.substring(0, 1))
        .width(44).height(44).textAlign(TextAlign.Center)
        .fontSize(20).fontColor('#FFFFFF').borderRadius(10)
        .backgroundColor(gameByGids(id).color)
      Text(gameByGids(id).name).layoutWeight(1).fontSize(16).fontColor('#101828')
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (selected) {
        if (id !== 5) {
          Text('⊖').fontSize(24).fontColor('#98A2B3').width(40).height(44)
            .textAlign(TextAlign.Center).onClick(() => this.remove(id))
        }
        Text('↑').fontSize(20).width(36).height(44).textAlign(TextAlign.Center)
          .fontColor(index === 0 ? '#D0D5DD' : '#667085')
          .enabled(index > 0).onClick(() => this.move(id, -1))
        Text('↓').fontSize(20).width(36).height(44).textAlign(TextAlign.Center)
          .fontColor(index === this.mine.length - 1 ? '#D0D5DD' : '#667085')
          .enabled(index < this.mine.length - 1).onClick(() => this.move(id, 1))
      } else {
        Text('⊕').fontSize(24).fontColor('#1570EF').width(44).height(44)
          .textAlign(TextAlign.Center).onClick(() => this.add(id))
      }
    }.width('100%').padding({ left: 12, right: 8, top: 12, bottom: 12 })
      .enabled(!this.saving)
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('←').fontSize(22).width(44).onClick(() => { if (!this.saving) { router.back(); } })
        Text(this.target === 'search' ? '社区频道设置' : '首页频道设置')
          .fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
        Text(this.saving ? '保存中' : '确定').fontSize(15).width(52).textAlign(TextAlign.End)
          .fontColor(this.dirty ? '#1570EF' : '#98A2B3')
          .enabled(this.dirty && !this.saving).onClick(() => this.commit())
      }.width('100%').height(56 + this.vp(this.safeTopPx))
        .padding({ top: this.vp(this.safeTopPx), left: 16, right: 16 })
        .backgroundColor(GlassTheme.barColor(this.glassLevel))
        .systemMaterial(GlassTheme.material(this.glassLevel))
      if (this.errorText !== '') { Text(this.errorText).fontSize(13).fontColor('#D92D20').padding(12) }
      Scroll() {
        Column({ space: 12 }) {
          Text('我的频道').fontSize(15).fontColor('#667085').width('100%')
          Column() {
            ForEach(this.mine, (id: number, index: number) => {
              this.ChannelRow(id, true, index)
            }, (id: number, index: number) => `${id}-${index}`)
          }.width('100%').backgroundColor('#FFFFFF').borderRadius(14)
          Text('推荐频道').fontSize(15).fontColor('#667085').width('100%').margin({ top: 8 })
          Column() {
            ForEach(this.recommended(), (g: GameInfo) => {
              this.ChannelRow(g.gids, false, 0)
            }, (g: GameInfo) => g.gids.toString())
            if (this.recommended().length === 0) {
              Text('所有频道都已加入').fontSize(13).fontColor('#98A2B3').padding(16)
            }
          }.width('100%').backgroundColor('#FFFFFF').borderRadius(14)
        }.width('100%').padding({ left: 16, right: 16, top: 16, bottom: 24 + this.vp(this.safeBottomPx) })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F7F8FA')
  }
}
