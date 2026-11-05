// 自适应比例图片：先按 16:9 预估比例占位（布局从首帧起稳定），
// onComplete 拿到真实宽高后按真实比例显示，不固定大小：
// - 常规图（0.7~2.4）：完整按真实比例显示（长图到 0.7 下限开始 Cover）
// - 横幅图（>2.4）：真实比例全显不横裁！按宽度档位控制高度预算（>8 限高 90、>4 限高 120、>2.4 限高 160），
//   内容分布在图片两侧的横幅不再被 Cover 居中裁剪
// - 极小图（<0.7 且真实尺寸小）：表情包/装饰图标，全显 + 限高 120，避免小图被拉成大图
// 点击时把在位的全局 rect 一并上报，供预览层做一镜到底优化动画。

// ArkTS 禁止内联对象字面量作类型声明，具名 interface 是必须的写法
interface ImageCompleteInfo {
  width: number;
  height: number;
}

export interface ThumbRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

@Component
export struct AdaptiveImage {
  imageUrl: string = '';
  radius: number = 10;
  onTap: (rect: ThumbRect) => void = () => {};
  @State ratio: number = 1.78;
  @State maxHeight: number = 0; // 0 = 不限高，走 Cover；>0 走 Contain 全显 + 限高
  private areaX: number = 0;
  private areaY: number = 0;
  private areaW: number = 0;
  private areaH: number = 0;

  private recordArea(_oldValue: Area, area: Area): void {
    const ctx = this.getUIContext();
    this.areaW = ctx.vp2px(Number(area.width));
    this.areaH = ctx.vp2px(Number(area.height));
    this.areaX = ctx.vp2px(Number(area.globalPosition.x));
    this.areaY = ctx.vp2px(Number(area.globalPosition.y));
  }

  private emitTap(): void {
    this.onTap({ x: this.areaX, y: this.areaY, w: this.areaW, h: this.areaH });
  }

  build() {
    if (this.maxHeight > 0) {
      Image(this.imageUrl)
        .width('100%')
        .constraintSize({ maxHeight: this.maxHeight })
        .aspectRatio(this.ratio)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#F2F4F7')
        .borderRadius(this.radius)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onComplete((event?: ImageCompleteInfo) => {
          this.adjust(event);
        })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.recordArea(oldValue, newValue);
        })
        .onClick(() => {
          this.emitTap();
        })
    } else {
      Image(this.imageUrl)
        .width('100%')
        .aspectRatio(this.ratio)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#F2F4F7')
        .borderRadius(this.radius)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onComplete((event?: ImageCompleteInfo) => {
          this.adjust(event);
        })
        .onAreaChange((oldValue: Area, newValue: Area) => {
          this.recordArea(oldValue, newValue);
        })
        .onClick(() => {
          this.emitTap();
        })
    }
  }

  private adjust(event?: ImageCompleteInfo): void {
    if (event === undefined || event.width <= 0 || event.height <= 0) {
      return;
    }
    const r = event.width / event.height;
    if (r > 8) {
      // 超细 banner/分隔条：真实比例全显，限高徽标化，不主导屏幕高度
      this.ratio = r;
      this.maxHeight = 90;
    } else if (r > 4) {
      // 宽横幅：真实比例全显不横裁，限高 120
      this.ratio = r;
      this.maxHeight = 120;
    } else if (r > 2.4) {
      // 一般横幅：真实比例全显不横裁，限高 160
      this.ratio = r;
      this.maxHeight = 160;
    } else if (r < 0.7 && event.height <= 480) {
      // 表情包/装饰小图：全显 + 限高，避免被放大成大图
      this.ratio = Math.max(0.3, r);
      this.maxHeight = 120;
    } else {
      // 常规 + 长截图：完整按真实比例，长图 Cover 到 0.7 下限
      this.ratio = Math.min(2.4, Math.max(0.7, r));
      this.maxHeight = 0;
    }
  }
}
