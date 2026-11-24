import SwiftUI

let brook = Color(red: 0.22, green: 0.43, blue: 0.44)
let ochre = Color(red: 0.63, green: 0.40, blue: 0.20)

func polygon(_ vertices: [[CGFloat]], size: CGSize) -> Path {
    Path { path in
        for (offset, pair) in vertices.enumerated() {
            let point = CGPoint(x: pair[0] * size.width, y: pair[1] * size.height)
            if offset == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
    }
}

func paperScale(_ size: CGSize) -> CGFloat {
    min(size.width, size.height * 1.14)
}

func paperPoint(_ pair: [Double], _ size: CGSize) -> CGPoint {
    let margin = paperScale(size) * 0.02
    return CGPoint(x: margin + pair[0] * (size.width - 2 * margin), y: pair[1] * size.height)
}

func portraitFrame(_ size: CGSize) -> CGRect {
    let width = min(paperScale(size) * 0.60, size.height * 0.55)
    let height = width * 0.79
    return CGRect(x: (size.width - width) / 2, y: size.height * 0.32 - height / 2,
                  width: width, height: height)
}

struct RicePaper: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 1, green: 0.966, blue: 0.88), paper,
                                Color(red: 0.91, green: 0.79, blue: 0.61)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Canvas { context, size in
                    for index in 0..<1700 {
                        let x = CGFloat((index * 419 + 19) % 2003) / 2003 * size.width
                        let y = CGFloat((index * 773 + 33) % 1999) / 1999 * size.height
                        var strand = Path()
                        strand.move(to: CGPoint(x: x, y: y))
                        strand.addLine(to: CGPoint(x: x + CGFloat(index % 9) + 1,
                                                   y: y + CGFloat(index % 4) - 1))
                        let color = index % 3 == 0 ? Color.white : ochre
                        context.stroke(strand, with: .color(color.opacity(0.16)), lineWidth: 0.55)
                    }
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

func markIcon(_ mark: String) -> String {
    switch mark {
    case "a": return "diamond"
    case "b": return "circle"
    case "c": return "triangle"
    default: return "square"
    }
}

struct SheetView: View {
    let sheet: Sheet
    let run: Attempt
    let tiger: Int
    let beat: TigerBeat?
    let selected: Int?
    let walking: Bool
    let select: (Int) -> Void
    let fold: (Int, Int) -> Void

    @State private var dragPanel: Int?
    @State private var dragTarget: Int?
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                BoardArt(sheet: sheet, run: run)
                ForEach(run.state.layers, id: \.self) { index in
                    let legal = run.accessible(sheet, index)
                    let pose = CGFloat(run.state.poses[index])
                    let activeDrag = dragPanel == index
                    let move = pose + (activeDrag ? progress : 0)
                    let frame = pieceRect(sheet, index, run.state.poses[index], size)
                    let panel = sheet.panels[index]
                    if run.visible(sheet, index) {
                        FoldPiece(sheet: sheet, panel: index, size: size, deployment: move,
                                  selected: selected == index, accessible: legal)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        if legal {
                            Button { select(index) } label: {
                                Color.clear.contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(width: max(46, min(frame.width, size.width * 0.24)),
                                   height: max(46, frame.height + 6))
                            .position(x: frame.midX, y: frame.midY)
                            .accessibilityLabel(word("edge.\(panel.id)"))
                            .accessibilityIdentifier("edge-\(panel.id)")
                            .accessibilityValue(word(["left.pose", "flat.pose", "right.pose"][run.state.poses[index] + 1]))
                            .accessibilityAddTraits(selected == index ? .isSelected : [])
                            .disabled(walking || run.won(sheet))
                            .simultaneousGesture(DragGesture(minimumDistance: 9)
                                .onChanged { drag in
                                    guard !walking && !run.won(sheet) else { return }
                                    if dragPanel == nil {
                                        select(index)
                                        dragPanel = index
                                    }
                                    guard dragPanel == index else { return }
                                    let start = facePoint(sheet, index, Int(pose), size, 0.5, 0.5)
                                    if dragTarget == nil {
                                        let candidates = [Int(pose) - 1, Int(pose) + 1].filter {
                                            run.canFold(sheet, index, $0)
                                        }
                                        var best: CGFloat = 0.20
                                        for target in candidates {
                                            let end = facePoint(sheet, index, target, size, 0.5, 0.5)
                                            let score = FoldAxis(start, end).alignment(from: start, to: end,
                                                                                       by: drag.translation)
                                            if score > best {
                                                best = score
                                                dragTarget = target
                                            }
                                        }
                                    }
                                    guard let target = dragTarget else { return }
                                    let end = facePoint(sheet, index, target, size, 0.5, 0.5)
                                    let angle = FoldAxis(start, end).pull(from: start, to: end, by: drag.translation)
                                    progress = CGFloat(target - Int(pose)) * min(0.96, angle)
                                }
                                .onEnded { _ in
                                    guard dragPanel == index else { return }
                                    let target = dragTarget
                                    let commit = abs(progress) >= 0.37
                                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                                        dragPanel = nil
                                        dragTarget = nil
                                        progress = 0
                                        if let target, commit { fold(index, target) }
                                    }
                                })
                            .transaction { change in
                                // Hit targets follow the settled state while the paper turns.
                                change.animation = nil
                                change.disablesAnimations = true
                            }
                        }
                    }
                }
                TigerOnPaper(sheet: sheet, run: run, node: tiger, beat: beat, size: size, walking: walking)
            }
        }
        // The paper is a physical object. The surrounding interface follows the locale.
        .environment(\.layoutDirection, .leftToRight)
    }
}

func pieceRect(_ sheet: Sheet, _ index: Int, _ pose: Int, _ size: CGSize) -> CGRect {
    let unit = paperScale(size)
    let faces = sheet.panels[index].faces
    let face = faces[pose + 1]
    let panel = sheet.panels[index]
    if let span = face.span {
        let left = paperPoint(sheet.points[span], size)
        let right = paperPoint(sheet.points[span + 1], size)
        let length = hypot(right.x - left.x, right.y - left.y) + 8
        let thickness = unit * 0.105
        return CGRect(x: (left.x + right.x - length) / 2, y: (left.y + right.y - thickness) / 2,
                      width: length, height: thickness)
    }
    let basePanel = sheet.panels.firstIndex { $0.id == panel.cover } ?? index
    var x = sheet.panels.count == 2 ? (basePanel == 0 ? 0.18 : 0.82) :
        [0.16, 0.84, 0.78, 0.22][basePanel]
    var y = sheet.panels.count == 2 ? 0.165 : [0.165, 0.165, 0.44, 0.44][basePanel]
    if panel.cover != nil && pose == 0 {
        if let lower = sheet.panels.firstIndex(where: { $0.id == panel.cover }) {
            let frame = pieceRect(sheet, lower, 0, size)
            x = frame.midX / size.width
            y = frame.midY / size.height
        }
        if panel.window != true { y += 0.009 }
    } else if pose != 0 {
        if let mark = face.mark {
            if sheet.panels.contains(where: { $0.window == true && $0.faces[1].mark == mark }) {
                x += Double(pose) * 0.074
            } else {
                let portrait = portraitFrame(size)
                let offsets: (CGFloat, CGFloat)
                switch mark {
                case "a": offsets = (-0.17, 0.035)
                case "b": offsets = (0.20, -0.26)
                case "c": offsets = (0.10, 0.31)
                default: offsets = (-0.24, 0.36)
                }
                x = (portrait.midX + portrait.width * offsets.0) / size.width
                y = (portrait.midY + portrait.height * offsets.1) / size.height
            }
        } else {
            x = min(0.88, max(0.12, x + Double(pose) * 0.13))
            y += 0.13
        }
    }
    if sheet.id == "stream" && panel.id == "tail" && pose == 0 {
        x = 0.74
        y = 0.535
    }
    let w = unit * (panel.cover != nil && pose == 0 && panel.window != true ? 0.215 : 0.187)
    let h = unit * (panel.cover != nil && pose == 0 && panel.window != true ? 0.154 : 0.133)
    return CGRect(x: x * size.width - w / 2, y: y * size.height - h / 2, width: w, height: h)
}

func mix(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

func localPoint(_ x: CGFloat, _ y: CGFloat, _ axis: CGPoint, _ cross: CGPoint, _ origin: CGPoint) -> CGPoint {
    CGPoint(x: origin.x + axis.x * x + cross.x * y, y: origin.y + axis.y * x + cross.y * y)
}

func outline(_ points: [CGPoint], closed: Bool = false) -> Path {
    Path { path in
        path.addLines(points)
        if closed { path.closeSubpath() }
    }
}

struct FoldAxis {
    let centre: CGPoint
    let normal: CGPoint
    let tangent: CGPoint

    init(_ first: CGPoint, _ last: CGPoint) {
        centre = mix(first, last, 0.5)
        let length = max(1, hypot(first.x - last.x, first.y - last.y))
        normal = CGPoint(x: (first.x - last.x) / length, y: (first.y - last.y) / length)
        tangent = CGPoint(x: -normal.y, y: normal.x)
    }

    func signedDistance(_ point: CGPoint) -> CGFloat {
        (point.x - centre.x) * normal.x + (point.y - centre.y) * normal.y
    }

    func mirror(_ point: CGPoint) -> CGPoint {
        localPoint(-2 * signedDistance(point), 0, normal, tangent, point)
    }

    func turn(_ start: CGPoint, _ end: CGPoint, _ t: CGFloat) -> (point: CGPoint, z: CGFloat) {
        // The little reserve pleat opens while the sheet is up. The fixed crease
        // remains the origin of the rotation, even for a longer bridge face.
        let reserve = t * t * (3 - 2 * t)
        let flat = mix(start, mirror(end), reserve)
        let depth = signedDistance(flat)
        let along = (flat.x - centre.x) * tangent.x + (flat.y - centre.y) * tangent.y
        let angle = t * .pi
        let z = depth * sin(angle)
        let surface = localPoint(depth * cos(angle), along, normal, tangent, centre)
        return (CGPoint(x: surface.x + z * 0.07, y: surface.y - z * 0.32), z)
    }

    func pull(from start: CGPoint, to end: CGPoint, by delta: CGSize) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, hypot(dx, dy))
        let along = (dx * delta.width + dy * delta.height) / length
        let reach = min(1, max(0, along / length))
        return acos(1 - 2 * reach) / .pi
    }

    func alignment(from start: CGPoint, to end: CGPoint, by delta: CGSize) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return (dx * delta.width + dy * delta.height) /
            max(1, hypot(dx, dy) * hypot(delta.width, delta.height))
    }
}

func facePoint(_ sheet: Sheet, _ panel: Int, _ pose: Int, _ size: CGSize, _ u: CGFloat, _ v: CGFloat) -> CGPoint {
    let frame = pieceRect(sheet, panel, pose, size)
    var angle: CGFloat = 0
    if let edge = sheet.panels[panel].faces[pose + 1].span {
        let a = paperPoint(sheet.points[edge], size)
        let b = paperPoint(sheet.points[edge + 1], size)
        angle = atan2(b.y - a.y, b.x - a.x)
    }
    let x = (u - 0.5) * frame.width
    let y = (v - 0.5) * frame.height
    return CGPoint(x: frame.midX + x * cos(angle) - y * sin(angle),
                   y: frame.midY + x * sin(angle) + y * cos(angle))
}

struct FoldPiece: View, Animatable {
    let sheet: Sheet
    let panel: Int
    let size: CGSize
    var deployment: CGFloat
    let selected: Bool
    let accessible: Bool

    var animatableData: CGFloat {
        get { deployment }
        set { deployment = newValue }
    }

    var body: some View {
        Canvas { context, _ in
            let pose = min(1, max(-1, deployment))
            let low = Int(floor(pose))
            let high = min(1, low + 1)
            let t = pose - CGFloat(low)
            let unit = paperScale(size)
            let isTurning = t > 0.001 && t < 0.999 && low != high
            let first = facePoint(sheet, panel, low, size, 0.5, 0.5)
            let last = facePoint(sheet, panel, high, size, 0.5, 0.5)
            let crease = FoldAxis(first, last)
            let projectedNormal = cos(t * .pi) + sin(t * .pi) *
                (crease.normal.x * 0.07 - crease.normal.y * 0.32)
            let back = projectedNormal < 0
            let visiblePose = back ? high : low
            let centreLine = facePoint(sheet, panel, low, size, 0, 0.5)
            let endLeft = facePoint(sheet, panel, high, size, 0, 0.5)
            let endRight = facePoint(sheet, panel, high, size, 1, 0.5)
            let mirrorLeft = crease.mirror(endLeft)
            let mirrorRight = crease.mirror(endRight)
            let flipU = hypot(mirrorRight.x - centreLine.x, mirrorRight.y - centreLine.y)
                < hypot(mirrorLeft.x - centreLine.x, mirrorLeft.y - centreLine.y)
            func vertex(_ u: CGFloat, _ v: CGFloat) -> (point: CGPoint, z: CGFloat) {
                if !isTurning { return (facePoint(sheet, panel, visiblePose, size, u, v), 0) }
                if back {
                    let start = facePoint(sheet, panel, low, size, flipU ? 1 - u : u, flipU ? v : 1 - v)
                    return crease.turn(start, facePoint(sheet, panel, high, size, u, v), t)
                }
                let end = facePoint(sheet, panel, high, size, flipU ? 1 - u : u, flipU ? v : 1 - v)
                return crease.turn(facePoint(sheet, panel, low, size, u, v), end, t)
            }
            let face = sheet.panels[panel].faces[visiblePose + 1]
            let punched = sheet.panels[panel].window == true
            var shape = outline(faceBorder.map { vertex($0.x, $0.y).point }, closed: true)
            if punched {
                let hole = (0..<24).map { i in
                    let angle = CGFloat(i) * .pi / 12
                    return vertex(0.475 + 0.195 * cos(angle), 0.5 + 0.30 * sin(angle)).point
                }
                shape.addPath(outline(hole, closed: true))
            }
            let z = max(0, vertex(0.5, 0.5).z)
            let turnLight = sin(t * .pi)
            let depthScale = min(1, z / max(1, unit * 0.24))

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: unit * (0.008 + depthScale * 0.018)))
                layer.fill(shape.offsetBy(dx: 2 + z * 0.21, dy: 3 + z * 0.64),
                           with: .color(ink.opacity(0.26 + depthScale * 0.08)), style: FillStyle(eoFill: true))
            }

            if isTurning {
                drawCrease(context, crease, lifted: vertex(0.5, 0.5).point, unit: unit, fold: turnLight)
            }

            let origin = vertex(0, 0).point
            let right = vertex(1, 0).point
            let bottom = vertex(0, 1).point
            var surface = context
            surface.transform = CGAffineTransform(a: right.x - origin.x, b: right.y - origin.y,
                                                   c: bottom.x - origin.x, d: bottom.y - origin.y,
                                                   tx: origin.x, ty: origin.y)
            drawSurface(surface, face: face, pose: visiblePose, punched: punched, raised: turnLight,
                        selected: selected)
            if isTurning {
                let corner = vertex(back && flipU ? 0.97 : 0.03, back && !flipU ? 0.12 : 0.88)
                context.fill(Path(ellipseIn: CGRect(x: corner.point.x - 1.4, y: corner.point.y - 1.4,
                                                   width: 2.8, height: 2.8)), with: .color(.white.opacity(0.78)))
            }
        }
    }

    private var faceBorder: [CGPoint] {
        [CGPoint(x: 0.05, y: 0), CGPoint(x: 0.95, y: 0), CGPoint(x: 1, y: 0.10),
         CGPoint(x: 1, y: 0.90), CGPoint(x: 0.95, y: 1), CGPoint(x: 0.05, y: 1),
         CGPoint(x: 0, y: 0.90), CGPoint(x: 0, y: 0.10)]
    }

    private func drawCrease(_ context: GraphicsContext, _ crease: FoldAxis, lifted: CGPoint,
                            unit: CGFloat, fold: CGFloat) {
        let width = unit * (0.036 + fold * 0.022)
        let a = localPoint(0, -width, crease.normal, crease.tangent, crease.centre)
        let b = localPoint(0, width, crease.normal, crease.tangent, crease.centre)
        let rootL = mix(a, lifted, 0.74)
        let rootR = mix(b, lifted, 0.74)
        let web = outline([a, b, rootR, rootL], closed: true)
        context.fill(web, with: .linearGradient(Gradient(colors: [paper.opacity(Double(fold) * 0.88),
                                                                   ochre.opacity(Double(fold) * 0.45)]),
                                                    startPoint: crease.centre, endPoint: lifted))
        context.stroke(outline([a, b]), with: .color(ink.opacity(0.54 * Double(fold))),
                       style: StrokeStyle(lineWidth: max(1.3, unit * 0.004), lineCap: .round))
        let ridge = outline([a, b]).offsetBy(dx: 1, dy: -1.3)
        context.stroke(ridge, with: .color(.white.opacity(0.8 * Double(fold))), lineWidth: 1.3)
    }

    private func drawSurface(_ context: GraphicsContext, face: Face, pose: Int, punched: Bool, raised: CGFloat,
                             selected: Bool) {
        var paperShape = outline(faceBorder, closed: true)
        if punched {
            paperShape.addEllipse(in: CGRect(x: 0.28, y: 0.20, width: 0.39, height: 0.60))
        }
        let pale = Color(red: 1, green: 0.95, blue: 0.79)
        let surface = pose < 0 ? Color(red: 0.78, green: 0.38, blue: 0.21) :
            (pose == 0 ? Color(red: 0.86, green: 0.68, blue: 0.42) : foil)
        context.fill(paperShape, with: .linearGradient(
            Gradient(colors: [pose < 0 ? paper : pale, surface, pose < 0 ? lacquer : ochre]),
            startPoint: .zero, endPoint: CGPoint(x: 0.94, y: 1)), style: FillStyle(eoFill: true))
        context.stroke(paperShape, with: .color(selected ? lacquer : ink.opacity(0.77)), lineWidth: 0.022)
        let ridge = outline([CGPoint(x: 0.06, y: 0.045), CGPoint(x: 0.93, y: 0.045)])
        context.stroke(ridge, with: .color(.white.opacity(0.44 + 0.41 * Double(raised))), lineWidth: 0.034)

        let box = CGSize(width: 1, height: 1)
        if face.span != nil {
            for slat in 1..<8 {
                let x = CGFloat(slat) / 8
                context.fill(polygon([[x,0.06],[x + 0.043,0.06],[x + 0.014,0.86],[x - 0.017,0.86]], size: box),
                             with: .color(ink.opacity(slat % 2 == 0 ? 0.57 : 0.31)))
            }
            context.stroke(outline([CGPoint(x: 0.015, y: 0.60), CGPoint(x: 0.985, y: 0.60)]),
                           with: .color(pale.opacity(0.92)), style: StrokeStyle(lineWidth: 0.040, dash: [0.022, 0.012]))
            return
        }

        let data = sheet.panels[panel]
        let fragment = face.mark ?? (pose == 0 ? data.faces.compactMap(\.mark).first : nil)
        if let fragment, !punched {
            let cutting: [[CGFloat]] = fragment == "a" ? [[0.07,0.25],[0.95,0.36],[0.94,0.87],[0.21,0.82]] :
                [[0.09,0.76],[0.31,0.31],[0.94,0.17],[0.83,0.76],[0.57,0.87]]
            let patch = polygon(cutting, size: box)
            context.fill(patch, with: .color(Color(red: 1, green: 0.78, blue: 0.30)))
            context.stroke(patch, with: .color(ink.opacity(0.55)), lineWidth: 0.017)
            if fragment == "a" {
                context.fill(polygon([[0.12,0.30],[0.80,0.53],[0.22,0.46]], size: box), with: .color(ink))
                context.fill(polygon([[0.15,0.57],[0.84,0.71],[0.22,0.71]], size: box), with: .color(ink))
            } else {
                context.fill(polygon([[0.19,0.69],[0.78,0.30],[0.69,0.68]], size: box), with: .color(ink))
                context.fill(polygon([[0.20,0.79],[0.65,0.74],[0.31,0.87]], size: box), with: .color(ink))
            }
        }
        if let mark = face.mark {
            let x: CGFloat = punched ? 0.83 : 0.19
            let y: CGFloat = punched ? 0.48 : 0.42
            let rect = CGRect(x: x - 0.09, y: y - 0.11, width: 0.18, height: 0.22)
            let symbol: Path
            switch mark {
            case "a":
                symbol = polygon([[0.5,0],[1,0.5],[0.5,1],[0,0.5]], size: rect.size)
                    .offsetBy(dx: rect.minX, dy: rect.minY)
            case "b": symbol = Path(ellipseIn: rect)
            case "c":
                symbol = polygon([[0.5,0],[1,1],[0,1]], size: rect.size)
                    .offsetBy(dx: rect.minX, dy: rect.minY)
            default: symbol = Path(rect)
            }
            context.stroke(symbol, with: .color(lacquer), lineWidth: 0.038)
        }
        if accessible && !punched {
            let grip = outline([CGPoint(x: 0.72, y: 0.18), CGPoint(x: 0.78, y: 0.23),
                                CGPoint(x: 0.84, y: 0.18)])
            context.stroke(grip, with: .color(selected ? lacquer : ink.opacity(0.72)),
                           style: StrokeStyle(lineWidth: 0.042, lineCap: .round, lineJoin: .round))
        }
    }
}

struct PrintThumbnail: View {
    let sheet: Sheet
    let run: Attempt
    let printed: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BoardArt(sheet: sheet, run: run, thumbnail: true)
                if printed {
                    ForEach(run.state.layers, id: \.self) { index in
                        if run.visible(sheet, index) {
                            FoldPiece(sheet: sheet, panel: index, size: geometry.size,
                                      deployment: CGFloat(run.state.poses[index]), selected: false, accessible: false)
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct BoardArt: View {
    let sheet: Sheet
    let run: Attempt
    var thumbnail = false

    var body: some View {
        ZStack {
            if thumbnail {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.84), paper,
                                                 Color(red: 0.9, green: 0.76, blue: 0.57)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Canvas { context, size in
                if thumbnail { fibers(context, size) }
                scene(context, size)
                portrait(context, size)
                trail(context, size)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func fibers(_ context: GraphicsContext, _ size: CGSize) {
        let w = size.width
        let h = size.height
        for index in 0..<(thumbnail ? 120 : 900) {
            let x = CGFloat((index * 149 + 33) % 997) / 997 * w
            let y = CGFloat((index * 283 + 55) % 991) / 991 * h
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + CGFloat(index % 7) + 1, y: y + CGFloat(index % 3) - 1))
            context.stroke(path, with: .color((index % 3 == 0 ? .white : ochre).opacity(0.14)), lineWidth: 0.5)
        }
        let edge = CGRect(x: w * 0.031, y: h * 0.029, width: w * 0.938, height: h * 0.938)
        context.stroke(Path(roundedRect: edge, cornerRadius: 4), with: .color(ochre.opacity(0.51)), lineWidth: 1)
        for pair in [[0.06,0.06],[0.94,0.06],[0.06,0.94],[0.94,0.94]] {
            let point = paperPoint(pair, size)
            context.fill(polygon([[0.5,0],[1,0.5],[0.5,1],[0,0.5]], size: CGSize(width: 8, height: 8))
                .offsetBy(dx: point.x - 4, dy: point.y - 4), with: .color(lacquer.opacity(0.62)))
        }
    }

    private func portrait(_ context: GraphicsContext, _ size: CGSize) {
        let w = size.width
        let h = size.height
        let box = portraitFrame(size)
        let unit = paperScale(size)
        let marks = run.marks(sheet)
        let complete = run.aligned(sheet)
        context.stroke(Path(ellipseIn: box), with: .color(ochre.opacity(0.54)), style: StrokeStyle(lineWidth: 0.85, dash: [2, 4]))
        let faceBox = box.insetBy(dx: box.width * 0.066, dy: box.height * 0.076)
        let mask = TigerArt().path(in: faceBox)
        if complete {
            context.fill(mask, with: .color(foil))
            context.stroke(mask, with: .color(ink.opacity(0.87)), lineWidth: 1.25)
        } else {
            context.stroke(mask, with: .color(ink.opacity(0.49)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        let nose = polygon([[0.42,0.53],[0.57,0.53],[0.52,0.65],[0.48,0.65]], size: faceBox.size)
            .offsetBy(dx: faceBox.minX, dy: faceBox.minY)
        let bib = polygon([[0.22,0.62],[0.47,0.64],[0.50,0.75],[0.53,0.64],[0.78,0.62],
                           [0.68,0.78],[0.50,0.88],[0.32,0.78]], size: faceBox.size)
            .offsetBy(dx: faceBox.minX, dy: faceBox.minY)
        if complete { context.fill(bib, with: .color(paper)) }
        context.fill(nose, with: .color(ink.opacity(complete ? 1 : 0.38)))
        for (index, key) in ["a", "b", "c", "d"].enumerated() where sheet.marks.contains(key) {
            let patch: [[[CGFloat]]] = [
                [[0.15,0.42],[0.51,0.47],[0.46,0.68],[0.17,0.63]],
                [[0.52,0.18],[0.83,0.15],[0.84,0.38],[0.57,0.41]],
                [[0.43,0.66],[0.71,0.66],[0.70,0.84],[0.43,0.82]],
                [[0.11,0.66],[0.39,0.66],[0.39,0.83],[0.12,0.83]]
            ]
            let impression = polygon(patch[index], size: faceBox.size).offsetBy(dx: faceBox.minX, dy: faceBox.minY)
            if !marks.contains(key) {
                context.stroke(impression, with: .color(lacquer.opacity(0.50)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
        }
        for (index, key) in sheet.marks.enumerated() {
            let shift = CGFloat(index) - CGFloat(sheet.marks.count - 1) / 2
            let symbol = Text(Image(systemName: marks.contains(key) ? "checkmark.seal.fill" : markIcon(key)))
                .font(.system(size: unit * 0.042, weight: .semibold))
                .foregroundColor(marks.contains(key) ? lacquer : ochre)
            context.draw(symbol, at: CGPoint(x: w / 2 + shift * unit * 0.098,
                                            y: box.maxY + h * 0.025))
        }
    }

    private func scene(_ context: GraphicsContext, _ size: CGSize) {
        let w = size.width
        let h = size.height
        let scene = sheet.scene
        let chapter = sheet.chapter
        let accent = [brook, lacquer, ochre, lacquer][chapter]
        if chapter == 1 {
            for i in 0..<3 {
                let x = (0.09 + Double(i) * 0.41) * w
                let y = (0.63 + Double((i + scene) % 3) * 0.10) * h
                let lantern = CGRect(x: x - w * 0.055, y: y, width: w * 0.11, height: h * 0.12)
                context.fill(Path(roundedRect: lantern, cornerRadius: w * 0.027), with: .color(foil.opacity(0.25)))
                context.stroke(Path(roundedRect: lantern, cornerRadius: w * 0.027), with: .color(accent.opacity(0.62)), lineWidth: 1.5)
                for rib in 1...3 {
                    let s = lantern.width * CGFloat(rib) / 7
                    context.stroke(Path(ellipseIn: lantern.insetBy(dx: s, dy: 0)), with: .color(accent.opacity(0.45)), lineWidth: 0.65)
                }
            }
        } else if chapter == 2 || chapter == 3 {
            for i in 0..<4 {
                let x = 0.03 + Double(i) * 0.27
                let y = 0.84 + Double((i + scene) % 3) * 0.023
                let roof = polygon([[x,y + 0.02],[x + 0.055,y],[x + 0.12,y - 0.056],[x + 0.18,y],[x + 0.23,y + 0.02],
                                    [x + 0.19,y + 0.029],[x + 0.034,y + 0.029]], size: size)
                context.fill(roof, with: .color(accent.opacity(0.38)))
                context.stroke(roof, with: .color(ink.opacity(0.55)), lineWidth: 0.72)
                var ribs = Path()
                for rib in 0..<6 {
                    let xx = (x + 0.053 + Double(rib) * 0.025) * w
                    ribs.move(to: CGPoint(x: xx, y: (y + 0.029) * h))
                    ribs.addLine(to: CGPoint(x: xx, y: (y + 0.082) * h))
                }
                context.stroke(ribs, with: .color(ochre.opacity(0.42)), lineWidth: 0.85)
            }
        } else {
            for i in 0..<10 {
                let x = (0.06 + Double((i * 29 + scene * 11) % 79) / 100) * w
                let y = (0.79 + Double((i * 13 + scene * 3) % 13) / 100) * h
                var stems = Path()
                for blade in -1...1 {
                    stems.move(to: CGPoint(x: x, y: y))
                    stems.addQuadCurve(to: CGPoint(x: x + Double(blade) * w * 0.016, y: y - Double(3 - abs(blade)) * h * 0.015),
                                       control: CGPoint(x: x + Double(blade) * w * 0.009, y: y - h * 0.016))
                }
                context.stroke(stems, with: .color(accent.opacity(0.56)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        for i in 0..<3 {
            var horizon = Path()
            let y = h * (0.13 + Double(i) * 0.029)
            horizon.move(to: CGPoint(x: w * 0.67, y: y))
            horizon.addQuadCurve(to: CGPoint(x: w * 0.91, y: y + h * 0.013),
                                 control: CGPoint(x: w * 0.78, y: y - h * 0.034))
            context.stroke(horizon, with: .color(accent.opacity(0.28)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }

    private func trail(_ context: GraphicsContext, _ size: CGSize) {
        let w = paperScale(size)
        let points = sheet.points.map { paperPoint($0, size) }
        let marks = run.marks(sheet)
        for edge in 0..<(points.count - 1) {
            let a = points[edge]
            let b = points[edge + 1]
            var path = Path()
            let isGap = sheet.gaps.contains(edge)
            let shortcut = sheet.shortGap == edge && sheet.shortMark.map { marks.contains($0) } == true
            if isGap {
                let x = (a.x + b.x) * 0.5
                let y = (a.y + b.y) * 0.5
                var water = Path()
                water.move(to: CGPoint(x: x - w * 0.068, y: y - w * 0.15))
                water.addCurve(to: CGPoint(x: x - w * 0.044, y: y + w * 0.25),
                               control1: CGPoint(x: x + w * 0.055, y: y - w * 0.05),
                               control2: CGPoint(x: x - w * 0.145, y: y + w * 0.14))
                let color = sheet.chapter < 2 ? brook : ochre
                context.stroke(water, with: .color(color.opacity(0.42)), style: StrokeStyle(lineWidth: w * 0.09, lineCap: .round))
                for n in [-1, 0, 1] {
                    context.stroke(water.offsetBy(dx: CGFloat(n) * w * 0.017, dy: 0), with: .color(paper.opacity(0.63)),
                                   style: StrokeStyle(lineWidth: 0.9, lineCap: .round, dash: [6, 7]))
                }
            }
            if !isGap || shortcut {
                path.move(to: a)
                path.addQuadCurve(to: b, control: routeControl(sheet, run, edge, size))
                context.stroke(path, with: .color(shortcut ? lacquer : ink.opacity(0.65)),
                               style: StrokeStyle(lineWidth: w * 0.008, lineCap: .round, dash: [2, 5]))
            } else {
                for p in [a, b] {
                    let rect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect), with: .color(paper))
                    context.stroke(Path(ellipseIn: rect), with: .color(lacquer), lineWidth: 1.5)
                }
            }
        }
        if let gate = points.last {
            let frame = CGRect(x: gate.x - w * 0.073, y: gate.y - w * 0.125, width: w * 0.146, height: w * 0.135)
            context.fill(polygon([[0.16,0.18],[0.30,0.18],[0.29,1],[0.18,1]], size: frame.size)
                .offsetBy(dx: frame.minX, dy: frame.minY), with: .color(lacquer))
            context.fill(polygon([[0.70,0.18],[0.84,0.18],[0.82,1],[0.71,1]], size: frame.size)
                .offsetBy(dx: frame.minX, dy: frame.minY), with: .color(lacquer))
            let roof = polygon([[0,0.21],[0.21,0.22],[0.31,0.04],[0.70,0.04],[0.81,0.22],[1,0.20],[0.89,0.39],[0.11,0.39]],
                               size: frame.size).offsetBy(dx: frame.minX, dy: frame.minY)
            context.fill(roof, with: .color(ink))
            context.stroke(roof, with: .color(foil), lineWidth: 1.2)
        }
    }
}

struct TigerArt: Shape {
    func path(in rect: CGRect) -> Path {
        polygon([[0.04,0.15],[0.23,0.21],[0.34,0.10],[0.66,0.10],[0.77,0.21],[0.96,0.15],
                 [0.92,0.47],[0.85,0.53],[0.83,0.72],[0.62,0.90],[0.38,0.90],[0.17,0.72],[0.15,0.53],[0.08,0.47]],
                size: rect.size).offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

enum TigerBeatKind {
    case rise, stride, brake, probe
}

struct TigerBeat {
    let kind: TigerBeatKind
    let node: Int
    let start: Date
    let duration: TimeInterval
    var cycles = 1
}

func routeControl(_ sheet: Sheet, _ run: Attempt, _ edge: Int, _ size: CGSize) -> CGPoint {
    let a = paperPoint(sheet.points[edge], size)
    let b = paperPoint(sheet.points[edge + 1], size)
    let isShort = sheet.shortGap == edge && sheet.shortMark.map { run.marks(sheet).contains($0) } == true
    let offset = isShort ? -0.075 : (sheet.gaps.contains(edge) ? 0 : 0.013)
    return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + paperScale(size) * offset)
}

func routeSample(_ sheet: Sheet, _ run: Attempt, _ edge: Int, _ s: CGFloat, _ size: CGSize) -> CGPoint {
    let a = paperPoint(sheet.points[edge], size)
    let b = paperPoint(sheet.points[edge + 1], size)
    let bend = routeControl(sheet, run, edge, size)
    if s <= 0 { return mix(a, bend, s * 2) }
    if s >= 1 { return mix(b, bend, (1 - s) * 2) }
    return mix(mix(a, bend, s), mix(bend, b, s), s)
}

struct TigerOnPaper: View {
    let sheet: Sheet
    let run: Attempt
    let node: Int
    let beat: TigerBeat?
    let size: CGSize
    let walking: Bool

    var body: some View {
        TimelineView(.animation(paused: beat == nil)) { timeline in
            Canvas { context, _ in
                let time = beat.map { timeline.date.timeIntervalSince($0.start) / $0.duration } ?? 1
                draw(context, phase: CGFloat(max(0, min(1, time))))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func draw(_ context: GraphicsContext, phase: CGFloat) {
        let w = paperScale(size) * 0.245
        let isStride = beat?.kind == .stride
        let edge = min(sheet.points.count - 2, beat?.node ?? node)
        let stage = isStride ? phase : (node == sheet.points.count - 1 ? 1 : 0)
        let base = routeSample(sheet, run, edge, stage, size)
        let waitingAtGap = node < sheet.points.count - 1 && sheet.gaps.contains(node)
        let probe = beat?.kind == .probe ? sin(.pi * phase) : 0
        let braking = beat?.kind == .brake ? sin(.pi * phase) : 0
        let cycles = CGFloat(beat?.cycles ?? 1)
        let gather = min(1, phase * 7, (1 - phase) * 7)
        let cadence = isStride ? gather : 0
        let wave = sin(phase * cycles * .pi * 4)
        let weight = cos(phase * cycles * .pi * 2)
        let rising = beat?.kind == .rise ? phase * phase * (3 - 2 * phase) : (run.state.released ? 1 : 0)
        let rise = 0.21 + 0.79 * rising
        let startMargin: CGFloat = waitingAtGap ? 0.13 : 0
        let endMargin: CGFloat = sheet.gaps.contains(edge + 1) ? 0.13 : 0
        let back = isStride ? startMargin * (1 - phase) + endMargin * phase : startMargin
        let x = min(size.width - w * 0.58, max(w * 0.61, base.x - back * w + probe * w * 0.06))
        let anchor = CGPoint(x: x, y: base.y - cadence * wave * w * 0.037 + braking * w * 0.031)
        let tilt = cadence * weight * 0.048 + probe * 0.095 + braking * 0.075
        let gold = Color(red: 0.95, green: 0.70, blue: 0.28)
        let farGold = Color(red: 0.65, green: 0.39, blue: 0.19)

        func joint(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: anchor.x + u * w, y: anchor.y + (v + tilt * u) * w * rise)
        }

        func facet(_ vertices: [[CGFloat]], tint: Color, stroke: Bool = false) {
            let shape = outline(vertices.map { joint($0[0], $0[1]) }, closed: true)
            context.fill(shape, with: .color(tint))
            if stroke { context.stroke(shape, with: .color(ink.opacity(0.68)), lineWidth: max(0.7, w * 0.007)) }
        }

        let shadow = CGRect(x: x - w * 0.44, y: base.y - w * 0.05, width: w * 0.94, height: w * 0.13)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: max(1, w * 0.027)))
            layer.fill(Path(ellipseIn: shadow), with: .color(ink.opacity(0.26)))
        }

        let offsets: [CGFloat] = [-0.24, 0.20, -0.17, 0.29]
        let rhythms: [CGFloat] = [0.25, 0.75, 0, 0.5]
        let distance = max(1, hypot(
            paperPoint(sheet.points[edge + 1], size).x - paperPoint(sheet.points[edge], size).x,
            paperPoint(sheet.points[edge + 1], size).y - paperPoint(sheet.points[edge], size).y
        ))

        func leg(_ i: Int, shade: Color) {
            let front = i % 2 == 1
            let near = i >= 2
            let offset = offsets[i]
            let hip = joint(front ? 0.23 : -0.25, front ? -0.31 : -0.29)
            let footLine = (near ? 0.045 : -0.016) * w * rising
            let atRest = CGPoint(x: x + offset * w, y: base.y + footLine)
            var paw = atRest
            var lift: CGFloat = 0
            if isStride {
                let clock = phase * cycles + rhythms[i]
                let whole = floor(clock)
                let fraction = clock - whole
                let cycleStart = (whole - rhythms[i] + 0.32) / cycles + offset * w / distance
                let planted = routeSample(sheet, run, edge, cycleStart, size)
                let target = routeSample(sheet, run, edge, cycleStart + 1 / cycles, size)
                let swing = max(0, (fraction - 0.64) / 0.36)
                let reach = swing * swing * (3 - 2 * swing)
                let moving = mix(planted, target, reach)
                paw = mix(atRest, CGPoint(x: moving.x, y: moving.y + footLine), cadence)
                lift = sin(.pi * swing) * w * 0.142 * cadence
            } else if i == 3 && beat?.kind == .probe {
                paw.x += w * 0.23 * probe
                if phase < 0.48 {
                    lift = sin(.pi * phase / 0.48) * w * 0.11
                } else if phase > 0.62 {
                    lift = sin(.pi * (phase - 0.62) / 0.38) * w * 0.10
                }
            }
            paw.y -= lift
            let knee = CGPoint(x: (hip.x + paw.x) / 2 + (front ? -0.085 : 0.104) * w * rise,
                               y: (hip.y + paw.y) / 2 + (front ? 0.01 : -0.016) * w * rise)
            let width = w * (near ? 0.050 : 0.040)
            let foot = CGRect(x: paw.x - w * 0.030, y: paw.y - w * 0.037,
                              width: w * 0.108, height: w * 0.057)
            let joints = [CGPoint(x: hip.x - width, y: hip.y),
                          CGPoint(x: hip.x + width, y: hip.y - width * 0.2),
                          CGPoint(x: knee.x + width * 0.65, y: knee.y),
                          CGPoint(x: paw.x + width * 0.43, y: paw.y - width * 0.16),
                          CGPoint(x: paw.x - width * 0.62, y: paw.y + width * 0.11),
                          CGPoint(x: knee.x - width * 0.60, y: knee.y)]
            context.fill(outline(joints, closed: true), with: .color(shade))
            context.stroke(outline(joints, closed: true), with: .color(ink.opacity(near ? 0.69 : 0.39)),
                           lineWidth: max(0.7, w * 0.007))
            context.fill(Path(roundedRect: foot, cornerRadius: w * 0.011), with: .color(shade))
            if lift < 0.01 * w {
                let ground = Path(ellipseIn: CGRect(x: paw.x - w * 0.024, y: paw.y + w * 0.017,
                                                    width: w * 0.092, height: w * 0.021))
                context.fill(ground, with: .color(ink.opacity(0.37)))
            }
        }

        leg(0, shade: farGold)
        leg(1, shade: farGold)
        let tail = -0.02 + cadence * weight * 0.079
        facet([[-0.29,-0.34],[-0.46,-0.43 + tail],[-0.57,-0.59 + tail],
               [-0.60,-0.53 + tail],[-0.51,-0.37 + tail],[-0.35,-0.25]], tint: ochre, stroke: true)
        facet([[-0.39,-0.42],[-0.22,-0.48],[0.17,-0.44],[0.30,-0.35],
               [0.24,-0.25],[-0.05,-0.19],[-0.34,-0.24]], tint: gold, stroke: true)
        facet([[-0.34,-0.28],[-0.05,-0.25],[0.23,-0.32],[0.24,-0.25],
               [-0.05,-0.19],[-0.34,-0.24]], tint: ochre.opacity(0.82))
        for i in 0...3 {
            let stripe = -0.34 + CGFloat(i) * 0.13
            facet([[stripe,-0.43],[stripe + 0.078,-0.455],[stripe + 0.05,-0.29]], tint: ink)
        }
        leg(2, shade: foil)
        leg(3, shade: foil)
        let dip = probe * 0.088 + braking * 0.033 + cadence * wave * 0.024
        facet([[0.17,-0.46 + dip],[0.19,-0.59 + dip],[0.29,-0.54 + dip],[0.44,-0.48 + dip],
               [0.54,-0.36 + dip],[0.46,-0.26 + dip],[0.27,-0.27 + dip],[0.15,-0.32 + dip]],
              tint: foil, stroke: true)
        facet([[0.36,-0.40 + dip],[0.53,-0.36 + dip],[0.46,-0.26 + dip],[0.33,-0.29 + dip]],
              tint: paper)
        facet([[0.28,-0.50 + dip],[0.41,-0.46 + dip],[0.34,-0.44 + dip]], tint: ink)
        facet([[0.50,-0.37 + dip],[0.54,-0.36 + dip],[0.51,-0.33 + dip]], tint: ink)
        if beat?.kind == .probe && phase > 0.47 && phase < 0.68 {
            let t = (phase - 0.47) / 0.21
            let contactX = x + w * 0.49
            let halo = CGRect(x: contactX - w * t * 0.12, y: base.y + w * 0.014,
                              width: w * t * 0.24, height: w * t * 0.069)
            context.stroke(Path(ellipseIn: halo), with: .color(lacquer.opacity(Double(1 - t) * 0.74)),
                           lineWidth: max(1, w * 0.012))
        }
        if run.won(sheet), !walking {
            let sparkle = Text(Image(systemName: "sparkle")).font(.system(size: w * 0.125)).foregroundColor(lacquer)
            context.draw(sparkle, at: joint(0.43, -0.62))
        }
    }
}
