import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Original layered app icon: doorway / portal with a directional play arrow.
let side: CGFloat = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

enum PortalLayer: String, CaseIterable {
    case frame = "Portal Frame"
    case gateway = "Gateway"
    case forward = "Forward"

    var filename: String {
        switch self {
        case .frame: "frame.png"
        case .gateway: "gateway.png"
        case .forward: "forward.png"
        }
    }

    var depth: Double {
        switch self {
        case .frame: 0.40
        case .gateway: 0.65
        case .forward: 1.00
        }
    }

    var tint: String {
        switch self {
        case .frame: "srgb:1.00000,0.89000,0.85000,1.00000"
        case .gateway: "srgb:1.00000,0.43000,0.40000,1.00000"
        case .forward: "srgb:1.00000,0.70000,0.51000,1.00000"
        }
    }
}

func render(_ layer: PortalLayer) -> CGImage {
    let ctx = CGContext(
        data: nil, width: Int(side), height: Int(side),
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setAllowsAntialiasing(true)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    switch layer {
    case .frame:
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 297, y: 286))
        p.addLine(to: CGPoint(x: 297, y: 742))
        p.addLine(to: CGPoint(x: 724, y: 742))
        p.addLine(to: CGPoint(x: 724, y: 286))
        ctx.addPath(p)
        ctx.setLineWidth(82)
        ctx.strokePath()
    case .gateway:
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 414, y: 399))
        p.addLine(to: CGPoint(x: 414, y: 625))
        p.addLine(to: CGPoint(x: 520, y: 625))
        p.addLine(to: CGPoint(x: 520, y: 399))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.fillPath()
    case .forward:
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 520, y: 360))
        p.addLine(to: CGPoint(x: 763, y: 512))
        p.addLine(to: CGPoint(x: 520, y: 664))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.fillPath()
    }
    return ctx.makeImage()!
}

func save(_ image: CGImage, url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}

func group(_ layer: PortalLayer) -> [String: Any] {
    [
        "blur-material": NSNull(),
        "layers": [[
            "fill": ["solid": layer.tint],
            "image-name": layer.filename,
            "name": layer.rawValue,
        ]],
        "opacity": 1,
        "refractivity": ["depth": layer.depth, "enabled": true, "strength": 0.005],
        "shadow": ["kind": "neutral", "opacity": 0.35],
        "specular": "inside",
        "translucency": ["enabled": true, "value": 0.22],
    ]
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: icon-generator <output.icon>\n".utf8))
    exit(2)
}
let document = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let assetDirectory = document.appendingPathComponent("Assets", isDirectory: true)
try? FileManager.default.removeItem(at: document)
try FileManager.default.createDirectory(at: assetDirectory, withIntermediateDirectories: true)
for part in PortalLayer.allCases {
    try save(render(part), url: assetDirectory.appendingPathComponent(part.filename))
}
let json: [String: Any] = [
    "features": ["refractivity", "specular-location"],
    "fill": ["linear-gradient": [
        "srgb:0.18000,0.20000,0.33000,1.00000",
        "srgb:0.05000,0.06000,0.10000,1.00000",
    ]],
    "groups": PortalLayer.allCases.map(group),
    "supported-platforms": ["circles": ["watchOS"], "squares": "shared"],
]
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    .write(to: document.appendingPathComponent("icon.json"))
