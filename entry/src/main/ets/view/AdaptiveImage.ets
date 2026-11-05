interface ImageCompleteInfo { width: number; height: number; }

export interface ThumbRect {
  x: number; y: number; w: number; h: number; r: number; iw: number; ih: number;
}

@Component
export struct AdaptiveImage {
  imageUrl: string = '';
  radius: number = 10;
  onTap: (rect: ThumbRect) => void = () => {};
  onLongPress: () => void = () => {};
  @State ratio: number = 1.78;
  @State maxHeight: number = 0;
  private areaX: number = 0;
  private areaY: number = 0;
  private areaW: number = 0;
  private areaH: number = 0;
  private imgW: number = 0;
  private imgH: number = 0;

  private recordArea(_old: Area, area: Area): void {
    this.areaW = Number(area.width); this.areaH = Number(area.height);
    this.areaX = Number(area.globalPosition.x); this.areaY = Number(area.globalPosition.y);
  }

  private emitTap(): void {
    this.onTap({ x: this.areaX, y: this.areaY, w: this.areaW, h: this.areaH, r: this.radius, iw: this.imgW, ih: this.imgH });
  }

  build() {
    if (this.maxHeight > 0) {
      Image(this.imageUrl).width('100%').constraintSize({ maxHeight: this.maxHeight }).aspectRatio(this.ratio)
        .objectFit(ImageFit.Contain).backgroundColor('#F2F4F7').borderRadius(this.radius)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onComplete((event?: ImageCompleteInfo) => this.adjust(event))
        .onAreaChange((old: Area, area: Area) => this.recordArea(old, area))
        .gesture(GestureGroup(GestureMode.Exclusive,
          LongPressGesture({ repeat: false }).onAction(() => this.onLongPress()),
          TapGesture().onAction(() => this.emitTap())
        ))
    } else {
      Image(this.imageUrl).width('100%').aspectRatio(this.ratio)
        .objectFit(ImageFit.Cover).backgroundColor('#F2F4F7').borderRadius(this.radius)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onComplete((event?: ImageCompleteInfo) => this.adjust(event))
        .onAreaChange((old: Area, area: Area) => this.recordArea(old, area))
        .gesture(GestureGroup(GestureMode.Exclusive,
          LongPressGesture({ repeat: false }).onAction(() => this.onLongPress()),
          TapGesture().onAction(() => this.emitTap())
        ))
    }
  }

  private adjust(event?: ImageCompleteInfo): void {
    if (event === undefined || event.width <= 0 || event.height <= 0) { return; }
    this.imgW = event.width; this.imgH = event.height;
    const r = event.width / event.height;
    if (r > 8) { this.ratio = r; this.maxHeight = 90; }
    else if (r > 4) { this.ratio = r; this.maxHeight = 120; }
    else if (r > 2.4) { this.ratio = r; this.maxHeight = 160; }
    else if (r < 0.7 && event.height <= 480) { this.ratio = Math.max(0.3, r); this.maxHeight = 120; }
    else { this.ratio = Math.min(2.4, Math.max(0.7, r)); this.maxHeight = 0; }
  }
}
