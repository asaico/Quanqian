import AppKit
import CoreGraphics
import CoreText

enum TextAlignmentOption: String, Codable, CaseIterable, Sendable {
    case left = "Left"
    case center = "Center"
    case right = "Right"

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}

nonisolated struct LayerTextStyle: Codable, Equatable, Sendable {
    var text: String = "输入文字"
    var fontName: String = "PingFangSC-Regular"
    var fontSize: CGFloat = 36
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var isBold: Bool = false
    var isItalic: Bool = false
    var isVertical: Bool = false
    var leading: CGFloat = 6
    var tracking: CGFloat = 0
    var alignment: TextAlignmentOption = .center

    // 描边属性
    var strokeEnabled: Bool = false
    var strokeRed: CGFloat = 1
    var strokeGreen: CGFloat = 1
    var strokeBlue: CGFloat = 1
    var strokeWidth: CGFloat = 3

    var color: PaletteColor {
        get { PaletteColor(red: red, green: green, blue: blue) }
        set {
            red = newValue.red
            green = newValue.green
            blue = newValue.blue
        }
    }

    var strokeColor: PaletteColor {
        get { PaletteColor(red: strokeRed, green: strokeGreen, blue: strokeBlue) }
        set {
            strokeRed = newValue.red
            strokeGreen = newValue.green
            strokeBlue = newValue.blue
        }
    }
}

nonisolated struct LayerText: Equatable, @unchecked Sendable {
    var style: LayerTextStyle
    let image: CGImage

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.style == rhs.style && lhs.image === rhs.image
    }

    static func loaded(_ style: LayerTextStyle?, image: CGImage?) -> LayerText? {
        guard let style, let image else { return nil }
        return LayerText(style: style, image: image)
    }

    /// 根据排版样式栅格化渲染出高清文字 CGImage
    static func renderImage(style: LayerTextStyle) throws -> CGImage {
        let content = style.text.isEmpty ? " " : style.text
        let fontSize = max(8, min(500, style.fontSize))
        
        // 构造基础字体
        var baseFont = NSFont(name: style.fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        let fontManager = NSFontManager.shared
        if style.isBold {
            baseFont = fontManager.convert(baseFont, toHaveTrait: .boldFontMask)
        }
        if style.isItalic {
            baseFont = fontManager.convert(baseFont, toHaveTrait: .italicFontMask)
        }

        let pad = style.strokeEnabled ? ceil(style.strokeWidth * 2) + 8 : 8

        if style.isVertical {
            return try renderVerticalText(content: content, font: baseFont, style: style, padding: pad)
        } else {
            return try renderHorizontalText(content: content, font: baseFont, style: style, padding: pad)
        }
    }

    private static func renderHorizontalText(content: String, font: NSFont, style: LayerTextStyle, padding: CGFloat) throws -> CGImage {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = style.alignment.nsAlignment
        paragraphStyle.lineSpacing = style.leading

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .kern: style.tracking
        ]

        let attrStr = NSAttributedString(string: content, attributes: attrs)
        let naturalSize = attrStr.size()
        let width = max(1, Int(ceil(naturalSize.width + padding * 2)))
        let height = max(1, Int(ceil(naturalSize.height + padding * 2)))

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            throw ExportError.render
        }

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        let drawRect = CGRect(x: padding, y: padding, width: CGFloat(width) - padding * 2, height: CGFloat(height) - padding * 2)

        // 描边遍
        if style.strokeEnabled && style.strokeWidth > 0 {
            var strokeAttrs = attrs
            let sColor = NSColor(srgbRed: style.strokeRed, green: style.strokeGreen, blue: style.strokeBlue, alpha: 1)
            strokeAttrs[.strokeColor] = sColor
            strokeAttrs[.strokeWidth] = style.strokeWidth * (100.0 / font.pointSize)
            let strokeStr = NSAttributedString(string: content, attributes: strokeAttrs)
            strokeStr.draw(in: drawRect)
        }

        // 填充主体遍
        var fillAttrs = attrs
        let fColor = NSColor(srgbRed: style.red, green: style.green, blue: style.blue, alpha: 1)
        fillAttrs[.foregroundColor] = fColor
        let fillStr = NSAttributedString(string: content, attributes: fillAttrs)
        fillStr.draw(in: drawRect)

        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = context.makeImage() else { throw ExportError.render }
        return cgImage
    }

    private static func renderVerticalText(content: String, font: NSFont, style: LayerTextStyle, padding: CGFloat) throws -> CGImage {
        // 漫画传统竖排排版：按 \n 分割为列，从右往左排列列，每列自上而下排字
        let rawLines = content.components(separatedBy: "\n")
        let lines = rawLines.isEmpty ? [" "] : rawLines
        let colCount = lines.count

        let charSize = ("国" as NSString).size(withAttributes: [.font: font])
        let colWidth = charSize.width + style.leading
        let rowHeight = charSize.height + style.tracking

        var maxCharsInCol = 1
        for line in lines {
            maxCharsInCol = max(maxCharsInCol, line.count)
        }

        let totalWidth = CGFloat(colCount) * colWidth + padding * 2
        let totalHeight = CGFloat(maxCharsInCol) * rowHeight + padding * 2
        let width = max(1, Int(ceil(totalWidth)))
        let height = max(1, Int(ceil(totalHeight)))

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            throw ExportError.render
        }

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        let fColor = NSColor(srgbRed: style.red, green: style.green, blue: style.blue, alpha: 1)
        let sColor = NSColor(srgbRed: style.strokeRed, green: style.strokeGreen, blue: style.strokeBlue, alpha: 1)

        for (colIdx, line) in lines.enumerated() {
            // 从右向左排布列
            let colX = CGFloat(width) - padding - CGFloat(colIdx + 1) * colWidth + (colWidth - charSize.width) / 2
            var currentY = CGFloat(height) - padding - charSize.height

            for char in line {
                let charStr = String(char)
                let charRect = CGRect(x: colX, y: currentY, width: charSize.width, height: charSize.height)

                if style.strokeEnabled && style.strokeWidth > 0 {
                    let strokeAttrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .strokeColor: sColor,
                        .strokeWidth: style.strokeWidth * (100.0 / font.pointSize)
                    ]
                    (charStr as NSString).draw(in: charRect, withAttributes: strokeAttrs)
                }

                let fillAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: fColor
                ]
                (charStr as NSString).draw(in: charRect, withAttributes: fillAttrs)

                currentY -= rowHeight
            }
        }

        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = context.makeImage() else { throw ExportError.render }
        return cgImage
    }
}

extension ImageLayer {
    /// 检查此图层是否依然保持为可再次排版编辑的文字图层
    var liveText: LayerText? {
        guard let text, let image = asset?.image, image === text.image else { return nil }
        return text
    }
}
