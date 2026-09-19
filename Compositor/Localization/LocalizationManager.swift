import SwiftUI
import AppKit

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case system = "system"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        case .system: return "跟随系统 (System)"
        }
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    private static let languageKey = "app_language"

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.languageKey)
            LocalizationTable.updateCachedLanguage(currentLanguage)
            applySystemLanguagePreference()
        }
    }

    /// 标记语言变更版本号，以便部分需要显式刷新的组件感知
    @Published var changeToken: Int = 0

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.languageKey)
        let initialLang = saved.flatMap(AppLanguage.init) ?? .simplifiedChinese
        self.currentLanguage = initialLang
        LocalizationTable.updateCachedLanguage(initialLang)
        applySystemLanguagePreference()
    }

    static func registerDefaults() {
        if UserDefaults.standard.string(forKey: languageKey) == nil {
            UserDefaults.standard.register(defaults: [
                languageKey: AppLanguage.simplifiedChinese.rawValue,
                "AppleLanguages": ["zh-Hans", "en"]
            ])
        }
    }

    private func applySystemLanguagePreference() {
        changeToken &+= 1
        switch currentLanguage {
        case .simplifiedChinese:
            UserDefaults.standard.set(["zh-Hans", "en"], forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en", "zh-Hans"], forKey: "AppleLanguages")
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    var isChinese: Bool {
        LocalizationTable.isChinese
    }

    nonisolated static func isCurrentChinese() -> Bool {
        LocalizationTable.isChinese
    }

    nonisolated static func tr(_ key: String) -> String {
        LocalizationTable.tr(key)
    }

    nonisolated static func format(_ key: String, _ arguments: CVarArg...) -> String {
        LocalizationTable.format(key, arguments)
    }

    func tr(_ key: String) -> String {
        LocalizationTable.tr(key)
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        LocalizationTable.format(key, arguments)
    }
}

// MARK: - 独立线程安全词典表（解耦 @Observable 宏）
enum LocalizationTable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var _cachedIsChinese: Bool = {
        let saved = UserDefaults.standard.string(forKey: "app_language")
        let lang = saved.flatMap(AppLanguage.init) ?? .simplifiedChinese
        switch lang {
        case .simplifiedChinese: return true
        case .english: return false
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
            return preferred.starts(with: "zh")
        }
    }()

    static func updateCachedLanguage(_ lang: AppLanguage) {
        let isZh: Bool
        switch lang {
        case .simplifiedChinese: isZh = true
        case .english: isZh = false
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
            isZh = preferred.starts(with: "zh")
        }
        lock.lock()
        _cachedIsChinese = isZh
        lock.unlock()
    }

    static var isChinese: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _cachedIsChinese
    }

    static func tr(_ key: String) -> String {
        if isChinese {
            return chineseTable[key] ?? key
        } else {
            return englishTable[key] ?? key
        }
    }

    static func format(_ key: String, _ arguments: [CVarArg]) -> String {
        let formatStr = tr(key)
        return String(format: formatStr, arguments: arguments)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        format(key, arguments)
    }

    // MARK: - 词典定义
    private static let englishTable: [String: String] = [:]

    private static let chineseTable: [String: String] = [
        // MARK: - 污点修复模式
        "Content-Aware": "内容识别",
        "Create Texture": "创建纹理",
        "Proximity Match": "近似匹配",

        // MARK: - 窗口与浮动面板
        "Window": "窗口",
        "Character": "字符",
        "Paragraph": "段落",
        "Character & Paragraph": "字符与段落",
        "History": "历史记录",
        "Initial State": "初始状态",
        "Jump to History State": "跳转到历史状态",

        // MARK: - 文字与段落排版
        "Text": "文字",
        "New Text Layer": "新建文字图层",
        "Text Content": "文本内容",
        "Font": "字体",
        "Font Size": "字号",
        "Leading": "行距",
        "Tracking": "字距",
        "Vertical Text": "竖排文字",
        "Horizontal Text": "横排文字",
        "Text Color": "文字颜色",
        "Stroke": "描边",
        "Stroke Width": "描边宽度",
        "Stroke Color": "描边颜色",
        "Bold": "加粗",
        "Italic": "倾斜",
        "Align Left": "左对齐",
        "Align Right": "右对齐",
        "Type text here…": "在此输入文字…",
        "Add Text Layer": "添加文字图层",
        "Edit Text": "编辑文字",
        "Apply Text": "应用文字",
        "Alignment": "对齐方式",
        "Editing Selected Layer": "正在编辑所选图层",
        "No history yet": "暂无历史记录",

        // MARK: - 应用与菜单
        "Check for Updates…": "检查更新…",
        "Hide Compositor": "隐藏 Compositor",
        "Hide Others": "隐藏其他",
        "Show All": "显示全部",
        "Settings…": "设置…",
        "Preferences…": "偏好设置…",

        // MARK: - 文件 (File)
        "New Canvas…": "新建画布…",
        "Open Project…": "打开项目…",
        "Import Images…": "导入图像…",
        "Save": "存储",
        "Save As…": "存储为…",
        "Export PNG…": "导出 PNG…",
        "Export JPEG…": "导出 JPEG…",
        "Close Project": "关闭项目",

        // MARK: - 撤销与重做 (Undo / Redo)
        "Undo": "撤销",
        "Redo": "重做",
        "Undo %@": "撤销 %@",
        "Redo %@": "重做 %@",

        // MARK: - 视图 (View)
        "Fit Canvas": "适合画布",
        "Actual Pixels": "实际像素",
        "Zoom In": "放大",
        "Zoom Out": "缩小",
        "Pixel Grid (800% and above)": "像素网格 (800%及以上)",
        "Show Transform Controls": "显示变换控件",

        // MARK: - 剪贴板与填充 (Pasteboard & Fill)
        "Cut": "剪切",
        "Copy": "拷贝",
        "Copy Merged": "合并拷贝",
        "Paste": "粘贴",
        "Fill with Foreground Color": "用前景色填充",
        "Fill with Background Color": "用背景色填充",
        "Clear Selection Pixels": "清除选区像素",
        "Content-Aware Fill…": "内容识别填充…",

        // MARK: - 选择 (Select)
        "Select": "选择",
        "All": "全部",
        "Deselect": "取消选择",
        "Inverse": "反向",
        "Layer's Pixels": "载入图层像素",
        "Mask's Black Areas": "载入蒙版黑色区域",
        "Expand by %d px": "扩展 %d 像素",
        "Contract by %d px": "收缩 %d 像素",

        // MARK: - 图像 (Image)
        "Image": "图像",
        "Curves…": "曲线…",
        "Levels…": "色阶…",
        "Hue/Saturation…": "色相/饱和度…",
        "Exposure…": "曝光度…",
        "Gradient Map…": "渐变映射…",
        "Grain…": "颗粒…",
        "Invert": "反相",
        "Invert Mask": "反向蒙版",
        "Canvas Size…": "画布大小…",
        "Image Size…": "图像大小…",
        "Flip Canvas Horizontal": "水平翻转画布",
        "Flip Canvas Vertical": "垂直翻转画布",

        // MARK: - 滤镜 (Filter)
        "Filter": "滤镜",
        "Gaussian Blur": "高斯模糊",
        "Gaussian Blur…": "高斯模糊…",
        "Motion Blur": "动感模糊",
        "Motion Blur…": "动感模糊…",
        "Add Noise": "添加杂色",
        "Add Noise…": "添加杂色…",
        "Lens Correction": "镜头校正",
        "Lens Correction…": "镜头校正…",
        "Remove Background": "移除背景",
        "Remove Background…": "移除背景…",
        "Content-Aware Fill": "内容识别填充",
        "Curves": "曲线",
        "Levels": "色阶",
        "Hue/Saturation": "色相/饱和度",
        "Exposure": "曝光度",
        "Gradient Map": "渐变映射",
        "Grain": "颗粒",

        // MARK: - 图层 (Layer)
        "Layer": "图层",
        "New Adjustment Layer": "新建调整图层",
        "Edit Adjustment…": "编辑调整…",
        "Transform Selection": "变换选区",
        "Transform Layer": "自由变换图层",
        "Duplicate Layer": "复制图层",
        "Layer via Copy": "通过拷贝建立图层",
        "Create Clipping Mask": "创建剪贴蒙版",
        "Release Clipping Mask": "释放剪贴蒙版",
        "Group Selected Layers": "将所选图层编组",
        "Move Out of Folder": "移出文件夹",
        "New Blank Layer": "新建空白图层",
        "Rename Layer…": "重命名图层…",
        "Show Layer": "显示图层",
        "Hide Layer": "隐藏图层",
        "Move Layer Up": "上移图层",
        "Move Layer Down": "下移图层",
        "Merge Down": "向下合并",
        "Merge Layers": "合并图层",
        "Merge Group": "合并图层组",
        "Flip Layer Horizontal": "水平翻转图层",
        "Flip Layer Vertical": "垂直翻转图层",
        "Delete Layer Mask": "删除图层蒙版",
        "Delete Layers": "删除图层",
        "Delete Layer": "删除图层",

        // MARK: - 工具栏与工具状态
        "New canvas": "新建画布",
        "New canvas (⌘N)": "新建画布 (⌘N)",
        "Fit": "适合窗口",
        "Fit canvas in window (⌘0)": "适合画布到窗口 (⌘0)",
        "100%": "100%",
        "Actual pixels (⌘1)": "实际像素 (⌘1)",
        "Zoom in (⌘+)": "放大 (⌘+)",
        "Zoom out (⌘−)": "缩小 (⌘−)",
        "Select a tool": "选择一个工具",
        "Ready when you are": "准备就绪",
        "Working…": "正在处理…",
        "Importing images…": "正在导入图像…",
        "sRGB · Transparent": "sRGB · 透明",

        // MARK: - 工具名称与快捷键提示 (NavigationTool)
        "Eyedropper (I)": "吸管 (I)",
        "Marquee (M)": "选框 (M)",
        "Lasso (L)": "套索 (L)",
        "Magic Wand (W)": "魔棒 (W)",
        "Brush (B) · Eraser (E)": "画笔 (B) · 橡皮擦 (E)",
        "Spot Healing Brush (J)": "污点修复画笔 (J)",
        "Clone Stamp (S) · Option-click sets the source": "仿制图章 (S) · 按住 Option 单击拾取源",
        "Smear (R)": "涂抹 (R)",
        "Gradient (G)": "渐变 (G)",
        "Shape (U) · Shift-U switches Rectangle/Ellipse": "形状 (U) · Shift-U 切换矩形/椭圆",
        "Crop (C)": "裁剪 (C)",
        "Move / Transform (V)": "移动 / 自由变换 (V)",
        "Hand (H)": "抓手 (H)",
        "Zoom (Z)": "缩放 (Z)",

        // 简写标题
        "Eyedropper": "吸管",
        "Sample Ring": "取样环",
        "Crop": "裁剪",
        "Pan": "平移",
        "Zoom": "缩放",
        "Transform": "自由变换",
        "Transform Mask": "变换蒙版",
        "Spot Healing": "污点修复",
        "Clone Stamp": "仿制图章",
        "Smear": "涂抹",
        "Eraser": "橡皮擦",
        "Brush": "画笔",
        "Shape": "形状",
        "Gradient": "渐变",
        "Marquee": "选框",
        "Magic Wand": "魔棒",
        "Lasso": "套索",

        // MARK: - 工具控制属性
        "Mode": "模式",
        "Type": "类型",
        "Aligned": "对齐",
        "Sample": "取样",
        "This Layer": "当前图层",
        "All Layers": "所有图层",
        "Size": "大小",
        "Hardness": "硬度",
        "Opacity": "不透明度",
        "Strength": "强度",
        "Paint": "绘制",
        "Color": "颜色",
        "Foreground color": "前景色",
        "Background color": "背景色",
        "Option-click to set the source": "按住 Option 单击拾取源",
        "Mask": "蒙版",
        "Black · Hide": "黑色 · 隐藏",
        "White · Reveal": "白色 · 显示",
        "Auto Select": "自动选择",
        "Show Controls": "显示控件",
        "Scale": "缩放",
        "Flip H": "水平翻转",
        "Flip V": "垂直翻转",
        "Sampling": "采样",
        "Lock aspect ratio": "锁定宽高比",
        "Radius": "圆角半径",
        "Fill": "填充",
        "Ratio": "比例",
        "Free": "自由",
        "Original": "原始比例",
        "Apply Crop": "应用裁剪",
        "Linear": "线性",
        "Radial": "径向",
        "Colors": "渐变色",
        "Reverse": "反向",
        "Anti-alias": "消除锯齿",
        "Expand": "扩展",
        "Contract": "收缩",
        "Empty selection": "空选区",
        "Tolerance": "容差",
        "Contiguous": "连续",
        "Sample All": "取样全部",
        "Zoom percentage": "缩放百分比",
        "Swap colors": "交换颜色",
        "Default colors": "默认颜色",
        "Swap foreground and background (X)": "交换前景色和背景色 (X)",
        "Default colors (D)": "默认颜色 (D)",
        "Mask background": "蒙版背景色",
        "Mask foreground": "蒙版前景色",

        // MARK: - 混合模式 (LayerBlendMode)
        "Normal": "正常",
        "Multiply": "正片叠底",
        "Screen": "滤色",
        "Overlay": "叠加",
        "Darken": "变暗",
        "Lighten": "变亮",
        "Difference": "差值",
        "Color Dodge": "颜色减淡",
        "Color Burn": "颜色加深",
        "Saturation": "饱和度",
        "Luminosity": "明度",
        "Blend": "混合",
        "Blend mode": "混合模式",
        "Opacity percent": "不透明度百分比",

        // MARK: - 图层面板 (Layers Panel)
        "Layers": "图层",
        "No layers yet": "暂无图层",
        "Create a canvas or import an image.": "创建画布或导入图像。",
        "Import an image or add a blank layer.": "导入图像或添加空白图层。",
        "New blank layer (⇧⌘N)": "新建空白图层 (⇧⌘N)",
        "New blank layer": "新建空白图层",
        "Group selected layers (⌘G)": "编组所选图层 (⌘G)",
        "New folder": "新建文件夹",
        "Add layer mask": "添加图层蒙版",
        "Add layer mask (the selection becomes black)": "添加图层蒙版 (选区变为黑色隐藏)",
        "New adjustment layer": "新建调整图层",
        "Delete layer mask": "删除图层蒙版",
        "Delete selected layers": "删除所选图层",
        "Delete selected layer": "删除所选图层",
        "Delete layer": "删除图层",
        "Drag to resize the panel": "拖动调整面板宽度",

        // MARK: - 图层列表上下文菜单 (NativeLayerList Context Menu)
        "Rename…": "重命名…",
        "Hide/Show Layer": "隐藏/显示图层",
        "Add White Mask": "添加白色蒙版 (全部显示)",
        "Add Black Mask": "添加黑色蒙版 (全部隐藏)",
        "Enable/Disable Mask": "启用/停用蒙版",
        "Delete Mask": "删除蒙版",
        "Delete Layer / Folder": "删除图层 / 文件夹",
        "Folder": "文件夹",
        "Adjustment · Double-click to edit": "调整图层 · 双击编辑",
        "Clipped to %@": "剪贴至 %@",
        "Clipping mask based on %@. Option-click the bottom of its row to release.": "基于 %@ 的剪贴蒙版。按住 Option 单击行底部可释放。",
        "Link layer and mask so they move together": "链接图层与蒙版，使其一同移动",
        "Unlink layer and mask to move or transform them separately": "取消链接，单独移动或变换",
        "Link mask: %@": "链接蒙版：%s",
        "Unlink mask: %@": "取消链接蒙版：%s",
        "Select image pixels": "选择图像像素",
        "Select layer mask; Shift-click to enable/disable; Cmd-click to select its black areas (Cmd-Shift adds, Cmd-Option subtracts)": "选择图层蒙版；按住 Shift 单击启用/停用；按住 Cmd 单击选择黑色区域 (Cmd-Shift 添加，Cmd-Option 减去)",
        "Select image: %@": "选择图像：%s",
        "Select mask: %@": "选择蒙版：%s",
        "Hide %@": "隐藏 %s",
        "Show %@": "显示 %s",
        "Expand or collapse folder": "展开或折叠文件夹",

        // MARK: - 项目标签页 (ProjectTabs)
        "New": "新建",
        "Drop to open in a new canvas": "拖放到此处在新建画布中打开",
        "Drop into new canvas": "拖入新建画布",
        "Unsaved changes": "未保存的更改",
        "Close %@": "关闭 %@",
        "Add to %@": "添加到 %@",
        "Open in a new project tab": "在新建项目标签页中打开",
        "New canvas (⌘N) · Drop images here for new tabs": "新建画布 (⌘N) · 拖放图像至此新建标签页",
        "Project tabs": "项目标签栏",
        "Untitled": "未命名",
        "Untitled %d": "未命名 %d",

        // MARK: - 新建画布 (NewCanvasSheet)
        "A blank space for your next composition.": "开始您的新构图创作。",
        "Width": "宽度",
        "Height": "高度",
        "px": "像素",
        "Transparent canvas · sRGB": "透明画布 · sRGB",
        "Enter whole numbers from 1 to 30,000 pixels.": "请输入 1 到 30,000 像素之间的整数。",
        "Open project": "打开项目",
        "Import image": "导入图像",
        "Create canvas": "创建画布",

        // MARK: - 画布大小 (CanvasSizeSheet)
        "Canvas Size": "画布大小",
        "Current: %d × %d pixels": "当前：%d × %d 像素",
        "%@ uncompressed RGBA canvas": "%@ 未压缩 RGBA 画布",
        "Units": "单位",
        "Pixels": "像素",
        "Percent": "百分比",
        "Inches": "英寸",
        "Centimeters": "厘米",
        "Relative to current dimensions": "相对当前尺寸",
        "Lock original aspect ratio": "锁定原始宽高比",
        "New: %d × %d pixels · %@ uncompressed": "新尺寸：%d × %d 像素 · %@ 未压缩",
        "Final dimensions must be 1–30,000 pixels per side.": "最终尺寸单边必须在 1–30,000 像素之间。",
        "Anchor": "定位锚点",
        "Keeps this point fixed. Artwork is not scaled; cropped content remains outside the canvas.": "固定此锚点。画面不会被缩放，超出部分将保留在画布外。",
        "Canvas extension": "画布扩展颜色",
        "Transparent": "透明",
        "Foreground": "前景色",
        "Background": "背景色",
        "Black": "黑色",
        "White": "白色",
        "Custom": "自定义",
        "Selected": "已选择",
        "Top left": "左上",
        "Top center": "中上",
        "Top right": "右上",
        "Middle left": "左中",
        "Center": "居中",
        "Middle right": "右中",
        "Bottom left": "左下",
        "Bottom center": "中下",
        "Bottom right": "右下",

        // MARK: - 图像大小 (ImageSizeSheet)
        "Image Size": "图像大小",
        "Resolution": "分辨率",
        "pixels/inch": "像素/英寸",
        "Resample": "重新采样",
        "High Quality (Bicubic)": "高品质 (双三次)",
        "Bilinear": "双线性",
        "Nearest Neighbor": "邻近 (硬边缘)",
        "Dimensions must be 1–30,000 pixels per side, up to 100 megapixels.": "单边必须在 1–30,000 像素之间，且总像素不超过 1 亿。",

        // MARK: - 导出 JPEG (JPEGExportSheet)
        "Export JPEG": "导出 JPEG",
        "Quality": "品质",
        "Background for transparency": "透明区域背景色",
        "· encoded preview, fitted to window": "· 编码预览，适合窗口",
        "Updating preview…": "正在更新预览…",
        "Export…": "导出…",

        // MARK: - 滤镜与调整面板通用
        "Preview": "预览",
        "Cancel": "取消",
        "OK": "好",
        "Applying…": "正在应用…",
        "Reset": "重置",
        "Limited to the selection": "仅作用于选区内",
        "Apply": "应用",

        // 曝光度与杂色
        "Offset": "位移",
        "Gamma": "灰度系数",
        "Amount": "数量",
        "Roughness": "粗糙度",
        "Distribution": "分布",
        "Uniform": "平均分布",
        "Monochromatic": "单色",
        "Remove Distortion": "校正畸变",
        "Positive straightens lines that bow outward (barrel); negative, lines that bow inward (pincushion).": "正值校正向外凸起的桶形畸变；负值校正向内凹陷的枕形畸变。",

        // 移除背景
        "Hide the background behind a layer mask, keeping the foreground subjects. The pixels stay, so the background can be painted back at any time.": "使用图层蒙版隐藏背景并保留前景主体。像素依然保留，可随时重新画回。",
        "Basic": "基础",
        "Advanced": "高级",
        "Basic is quick; Advanced refines the mask against the layer's own detail, for hair and fur": "“基础”速度更快；“高级”结合图层细节精细优化蒙版边缘，适用于头发与毛发。",
        "Refine": "边缘精细",
        "Contrast": "蒙版对比度",
        "Shift Edge": "移动边缘",
        "Pull the mask onto the image's own edges, which recovers hair and fur": "向主体边缘拉伸蒙版，以恢复发丝和毛发细节",
        "Clear the haze that leaves background showing through thin areas": "消除半透明区域残留的背景泛白/杂色",
        "Shrink the mask to drop the rim of background color around the subject, or grow it": "向内收缩蒙版以去除主体周围的背景杂边，或向外扩展",

        // 内容识别填充
        "Fill the selection using surrounding pixels from this layer.": "使用当前图层选区周围的像素自动进行内容识别填充。",

        // 色阶 (Levels)
        "Channel": "通道",
        "RGB": "RGB",
        "Red": "红",
        "Green": "绿",
        "Blue": "蓝",
        "Loading histogram…": "正在加载直方图…",
        "Input black": "输入黑色",
        "Input white": "输入白色",
        "Output black": "输出黑色",
        "Output white": "输出白色",
        "Black Point": "黑场",
        "Gray Point": "灰场",
        "White Point": "白场",
        "Auto": "自动",
        "Enhance Contrast": "增强对比度",
        "Enhance Colors": "增强各通道对比度",
        "Find Dark & Light": "寻找深色与浅色",
        "Click the original layer to set %@. Click the eyedropper again to stop.": "单击原始图层拾取%@。再次单击吸管停止拾取。",
        "Underlying pixels · alpha-weighted histogram": "底层像素 · Alpha 加权直方图",
        "Original pixels · alpha-weighted histogram": "原始像素 · Alpha 加权直方图",
        "Original pixels · selection and alpha-weighted histogram": "原始像素 · 选区与 Alpha 加权直方图",

        // 色相/饱和度 (Hue/Saturation)
        "Range": "范围",
        "Master": "全图",
        "Reds": "红色",
        "Yellows": "黄色",
        "Greens": "绿色",
        "Cyans": "青色",
        "Blues": "蓝色",
        "Magentas": "洋红",
        "Hue": "色相",
        "Lightness": "明度",
        "Apply outside this range instead": "反转作用范围",
        "Colorize": "着色",
        "Targeted adjustment: drag on the image to change that color's saturation, or its hue with Command held": "定向调整：在图像上拖动调整该颜色的饱和度，按住 Command 拖动调整其色相",
        "Targeted adjustment": "定向调整",
        "%@ color": "%@颜色",

        // 拾色器 (ColorPicker)
        "Click the canvas to sample": "单击画布拾取颜色",

        // MARK: - 项目控制器与弹窗 (ProjectController)
        "Export PNG": "导出 PNG",
        "Save Project": "存储项目",
        "Save Project As": "项目另存为",
        "Open Project": "打开项目",
        "Save changes to %@?": "是否存储对“%@”的更改？",
        "Your changes will be lost if you don’t save them.": "如果不存储，您的更改将会丢失。",
        "Don’t Save": "不存储",
        "Couldn’t export PNG": "无法导出 PNG",
        "Couldn’t export JPEG": "无法导出 JPEG",
        "Couldn’t change canvas size": "无法更改画布大小",
        "Couldn’t resize the image": "无法调整图像大小",
        "Couldn’t save the project": "无法存储项目",
        "Couldn’t open the project": "无法打开项目",
        "Open one project at a time": "一次只能打开一个项目",
        "Import couldn’t finish": "导入无法完成",
        "Couldn’t paint": "无法绘制",
        "Couldn’t crop": "无法裁剪",
        "The copied layers exceed this project’s 100-megapixel limit.": "复制的图层超过了此项目 100 兆像素（1亿像素）的上限。",

        // MARK: - 动作与撤销历史名称 (DocumentHistory Names)
        "Edit": "编辑",
        "Brush Stroke": "画笔描边",
        "Erase": "橡皮擦",
        "Blur": "模糊",
        "Paint Mask": "绘制蒙版",
        "Move Layer": "移动图层",
        "Move Layers": "移动图层",
        "Reorder Layers": "重新排列图层",
        "New Folder": "新建文件夹",
        "Group Layers": "编组图层",
        "Layer Opacity": "图层不透明度",
        "Layer Blend Mode": "图层混合模式",
        "Flip Horizontal": "水平翻转",
        "Flip Vertical": "垂直翻转",
        "New Canvas": "新建画布",
        "Import Image": "导入图像",
        "Import Images": "导入图像",
        "Copy Layers from Project": "从项目复制图层",
        "Distort": "扭曲",
        "Distort Layers": "扭曲图层",
        "Move Selection": "移动选区",
        "Add Mask from Selection": "从选区添加蒙版",
        "Add Reveal-All Mask": "添加全部显示蒙版",
        "Add Hide-All Mask": "添加全部隐藏蒙版",
        "Disable Layer Mask": "停用图层蒙版",
        "Enable Layer Mask": "启用图层蒙版",
        "Copy Layer Mask": "复制图层蒙版",
        "Replace Layer Mask": "替换图层蒙版",
        "Edit %@ Adjustment": "编辑%@调整",
        "New %@ Adjustment": "新建%@调整",

        // MARK: - 偏好设置
        "Language": "语言",
        "Language / 语言": "语言 / Language",
        "General": "通用",
        "Appearance": "外观",
        "Interface Language": "界面语言",
        "Language changes take effect immediately across all windows.": "语言切换会立即在所有窗口和菜单生效。",
        "Compositor Settings": "Compositor 设置",
        "About": "关于",
        "Version %@ (%@)": "版本 %@ (%@)",
        "Open-source image editor": "开源图像编辑器",

        // MARK: - 形状与渐变类型
        "Rectangle": "矩形",
        "Ellipse": "椭圆",
        "Freehand": "自由套索",
        "Polygonal": "多边形套索",
        "Replace": "新选区",
        "Add": "添加到选区",
        "Subtract": "从选区减去",
        "Intersect": "与选区交叉",
        "Press M to switch between Rectangle and Ellipse": "按 M 键在矩形和椭圆之间切换",
        "Press L to switch between Freehand and Polygonal": "按 L 键在自由套索和多边形套索之间切换",
        "Hold Shift to add or Option to subtract for one outline": "按住 Shift 增加选区，按住 Option 减去选区",
        "Smooth selection edges; turn off for hard pixel edges": "平滑选区边缘；关闭可得到硬像素边缘",
        "How far each color channel (0–255) can differ from the clicked color and still be selected": "所选颜色与单击像素允许的最大色差容差 (0–255)",
        "Point Sample": "取样点",
        "3 by 3 Average": "3×3 平均",
        "5 by 5 Average": "5×5 平均",
        "Sample Size": "取样大小",
        "Match the clicked pixel, or the average of the pixels around it": "匹配单击的单个像素，或周围像素的平均值",
        "Read colors from the active layer only, or from every visible layer as shown": "仅从当前活动图层读取颜色，或从所有可见图层读取",
        "Select only similar pixels connected to the one you click; off selects them everywhere": "仅选择与单击处相连的相似像素；关闭则选择全图所有相似像素",
        "%@ the selection by this many pixels": "%@选区指定像素量",
        "Linear runs along the line; Radial spreads out from the start point": "线性渐变沿直线过渡；径向渐变从起点向四周扩散",
        "Foreground to Background": "前景色到背景色",
        "Foreground to Transparent": "前景色到透明",
        "Press 1–9 for 10–90%, 0 for 100%": "按数字键 1–9 设置 10–90%，按 0 设置 100%",
        "Shift-U switches between Rectangle and Ellipse": "按 Shift-U 键在矩形和椭圆之间切换",
        "Round the rectangle's corners by this many pixels; 0 keeps them square": "矩形圆角半径（像素）；0 为直角",
        "Shapes fill with the foreground color; click to change it": "形状以当前前景色填充；单击可更改",
        "Zoom percentage (0.1–3200%). Press Return to apply.": "缩放比例 (0.1–3200%)。按回车键应用。",
        "Release clipping mask": "释放剪贴蒙版",
        "Create clipping mask": "创建剪贴蒙版",
        "Resize": "调整大小",
        "Result: %d × %d pixels": "结果：%d × %d 像素",
        "Use 1–30,000 pixels per side, up to 100 megapixels, and 1–9,600 pixels/inch.": "单边需在 1–30,000 像素之间，上限 1 亿像素，分辨率 1–9,600 像素/英寸。",
        "Resizes layer pixels and applies existing transforms. Undo restores the originals.": "缩放图层像素并应用当前变换。可通过撤销恢复原始内容。",
        "Only print dimensions and resolution change. Pixels stay unchanged.": "仅更改打印尺寸与分辨率，画面实际像素保持不变。",
        "Shadows": "阴影",
        "Highlights": "高光",
        "Choose the %@ color": "选择%@颜色",
        "Click to add a point. Drag to adjust.": "单击添加控制点。拖动进行调整。",
        "Input %d · Output %d": "输入 %d · 输出 %d",
        "Remove point": "删除控制点",
        "Reset curve": "重置曲线",
        "Linear histogram with automatic vertical scaling. Tall spikes may extend beyond the graph; all tones from 0 to 255 remain included.": "自动纵向缩放的线性直方图。极高波峰可能超出图表顶部，但 0 至 255 的所有明暗色调均已完整包含。",
        "Color Picker (Background Color)": "选取背景色",
        "Color Picker (Foreground Color)": "选取前景色",
        "Color Picker (Gradient Map Highlights)": "选取高光渐变映射颜色",
        "Color Picker (Gradient Map Shadows)": "选取阴影渐变映射颜色",
        "Saturation and brightness": "饱和度与明度",
        "Hex color": "十六进制颜色",
        "New color": "新颜色",
        "That selection is too detailed to outline. Try a different Tolerance, or turn on Contiguous.": "该选区过于复杂，无法描绘轮廓。请尝试调整容差，或开启“连续”。",
        "There isn’t enough memory to make that selection.": "内存不足，无法完成该选区。",
        "Enhance Monochromatic Contrast": "增强单色对比度",
        "Enhance Per Channel Contrast": "增强各通道对比度",
        "Find Dark & Light Colors": "寻找深色与浅色",
        "Click the image to center this range on that color": "单击图像将当前调整范围中心对齐到该颜色",
        "Click the image to widen this range to include that color": "单击图像扩展调整范围以包含该颜色",
        "Click the image to narrow this range to exclude that color": "单击图像收缩调整范围以排除该颜色",
        "Original %@ histogram": "原始%@直方图",
        "You are currently running the latest version.": "当前已是最新版本。"
    ]
}

extension String {
    var localized: String {
        LocalizationTable.tr(self)
    }
}
