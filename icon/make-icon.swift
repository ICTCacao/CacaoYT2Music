// アプリアイコンを描く。使い方: swift make-icon.swift <out.png>
import Foundation
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let canvas: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r/255, green: g/255, blue: b/255, alpha: a)
}
let cacaoTop = rgb(139, 82, 58)     // ICTCacao ロゴのブラウン
let cacaoBottom = rgb(92, 50, 34)
let cream = rgb(246, 233, 220)
let accent = rgb(240, 168, 76)      // オレンジ（CacaoTrans と同系）

// 1. 角丸の土台
let inset: CGFloat = 100
let base = NSRect(x: inset, y: inset, width: canvas - inset*2, height: canvas - inset*2)
let squircle = NSBezierPath(roundedRect: base, xRadius: base.width * 0.225, yRadius: base.width * 0.225)
ctx.saveGState()
squircle.addClip()
NSGradient(starting: cacaoTop, ending: cacaoBottom)!.draw(in: base, angle: -90)
NSGradient(starting: NSColor(white: 1, alpha: 0.10), ending: NSColor(white: 1, alpha: 0))!
    .draw(in: NSRect(x: base.minX, y: base.midY, width: base.width, height: base.height/2), angle: -90)
ctx.restoreGState()

// 2. カバー画像のカード（クリーム色・角丸・影）。中に音符
let card = NSRect(x: 262, y: 330, width: 500, height: 500)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 34, color: NSColor(white: 0, alpha: 0.32).cgColor)
cream.setFill()
NSBezierPath(roundedRect: card, xRadius: 56, yRadius: 56).fill()
ctx.restoreGState()

// 音符（連桁つきの八分音符 2 つ）
let ink = cacaoTop
ink.setFill()
let noteW: CGFloat = 122, noteH: CGFloat = 92
let stemW: CGFloat = 34
let leftX = card.minX + 130, rightX = card.maxX - 130
let headY = card.minY + 110
for cx in [leftX, rightX] {
    let head = NSBezierPath(ovalIn: NSRect(x: cx - noteW/2, y: headY - noteH/2, width: noteW, height: noteH))
    let t = NSAffineTransform(); t.translateX(by: cx, yBy: headY); t.rotate(byDegrees: -20); t.translateX(by: -cx, yBy: -headY)
    head.transform(using: t as AffineTransform)
    head.fill()
    NSBezierPath(roundedRect: NSRect(x: cx + noteW/2 - stemW - 8, y: headY, width: stemW, height: 270), xRadius: stemW/2, yRadius: stemW/2).fill()
}
// 連桁（右上がり）
let beam = NSBezierPath()
let bx0 = leftX + noteW/2 - stemW - 8, bx1 = rightX + noteW/2 - 8
let by = headY + 270 - 12
beam.move(to: NSPoint(x: bx0, y: by - 34)); beam.line(to: NSPoint(x: bx1, y: by - 34 + 40))
beam.line(to: NSPoint(x: bx1, y: by + 30 + 40)); beam.line(to: NSPoint(x: bx0, y: by + 30)); beam.close()
beam.fill()

// 3. 下: 下向きの矢印（保存する）とトレー
accent.setFill()
let ax = canvas / 2
let arrowTop: CGFloat = 300, arrowShaftW: CGFloat = 44
NSBezierPath(roundedRect: NSRect(x: ax - arrowShaftW/2, y: 212, width: arrowShaftW, height: arrowTop - 212), xRadius: arrowShaftW/2, yRadius: arrowShaftW/2).fill()
let head = NSBezierPath()
head.move(to: NSPoint(x: ax - 78, y: 236)); head.line(to: NSPoint(x: ax + 78, y: 236)); head.line(to: NSPoint(x: ax, y: 168)); head.close()
head.fill()
cream.setFill()
NSBezierPath(roundedRect: NSRect(x: 230, y: 150, width: canvas - 460, height: 22), xRadius: 11, yRadius: 11).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
