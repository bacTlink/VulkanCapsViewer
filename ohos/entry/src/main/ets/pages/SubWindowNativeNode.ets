interface SubWindowNativeNodeCreateInfo {
  xComponentId: string
  onAppear: () => void
  onDisAppear: () => void
}

@Entry
@Component
struct SubWindowNativeNode {
  @State private createInfo: SubWindowNativeNodeCreateInfo | undefined = undefined

  aboutToAppear(): void {
    const localStorage  = this.getUIContext().getSharedLocalStorage();
    if (localStorage ) {
      this.createInfo = localStorage.get<SubWindowNativeNodeCreateInfo>('createInfo');
    }
  }

  build() {
    Stack() {
      if (this.createInfo !== undefined) {
        XComponent({
          type: XComponentType.NODE,
          id: this.createInfo.xComponentId,
          libraryname: 'qohos'
        })
        .onAppear(this.createInfo.onAppear)
        .onDisAppear(this.createInfo.onDisAppear)
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    // Opaque background, visible in the gaps of the ARGB native buffer
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
