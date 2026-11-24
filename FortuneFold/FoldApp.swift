import SwiftUI
import AVFoundation

let ink = Color(red: 0.19, green: 0.14, blue: 0.12)
let paper = Color(red: 0.96, green: 0.89, blue: 0.78)
let lacquer = Color(red: 0.66, green: 0.19, blue: 0.16)
let foil = Color(red: 0.84, green: 0.65, blue: 0.28)
let charcoal = Color(red: 0.15, green: 0.11, blue: 0.10)

func word(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func count(_ key: String, _ value: Int) -> String {
    String(format: word(key), locale: .current, value)
}

func titleFace(_ size: CGFloat) -> Font {
    .system(size: size, weight: .regular, design: .serif)
}

func smallFace(_ size: CGFloat = 11) -> Font {
    .system(size: size, weight: .semibold, design: .monospaced)
}

final class PaperSound {
    private let queue = DispatchQueue(label: "FortuneFold.PaperSound")
    private var players: [String: AVAudioPlayer] = [:]

    init() {
        #if !targetEnvironment(simulator)
        queue.async { [self] in
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            for name in ["paper", "seal", "paw", "bridge"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                   let player = try? AVAudioPlayer(contentsOf: url) {
                    player.volume = name == "paw" ? 0.30 : (name == "bridge" ? 0.57 : 0.48)
                    player.prepareToPlay()
                    players[name] = player
                }
            }
        }
        #endif
    }

    func play(_ name: String, tactile: Bool = true) {
        #if DEBUG
        NSLog("FF_AUDIO %@ %.3f", name, Date().timeIntervalSince1970)
        #endif
        #if !targetEnvironment(simulator)
        if tactile { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        queue.async { [self] in
            guard let player = players[name] else { return }
            player.currentTime = 0
            player.play()
        }
        #endif
    }
}

@main
struct FoldApp: App {
    var body: some Scene {
        WindowGroup {
            DeskView()
                .preferredColorScheme(.dark)
        }
    }
}

struct DeskView: View {
    @State private var save: DeskSave
    @State private var screen: String
    @State private var chapter = 0
    @State private var selectedID: String?
    @State private var selectedEdge: Int?
    @State private var notice = ""
    @State private var displayTiger = 0
    @State private var walking = false
    @State private var tigerBeat: TigerBeat?
    @State private var walkTask: Task<Void, Never>?
    @State private var envelopeLift: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let campaign: [Sheet]
    private let storage: URL
    @State private var sound = PaperSound()

    init() {
        let url = Bundle.main.url(forResource: "Campaign", withExtension: "json")!
        let sheets = try! readCampaign(from: url)
        campaign = sheets
        storage = URL.applicationSupportDirectory.appending(path: "desk-v1.json")
        let restored = (try? Data(contentsOf: storage)).flatMap {
            try? JSONDecoder().decode(DeskSave.self, from: $0)
        }
        let valid = restored.flatMap { data in
            sheets.contains(where: { $0.id == data.sheetID }) ? data : nil
        }
        _save = State(initialValue: valid ?? DeskSave(sheet: sheets[0]))
        _screen = State(initialValue: valid?.opened == true ? "desk" : "envelope")
        _displayTiger = State(initialValue: valid?.attempt.state.tiger ?? 0)
    }

    private var sheet: Sheet { campaign.first { $0.id == save.sheetID } ?? campaign[0] }
    private var run: Attempt { save.attempt }
    private var number: Int { (campaign.firstIndex { $0.id == sheet.id } ?? 0) + 1 }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if screen == "sheet" {
                    RicePaper()
                    game(size: geometry.size)
                } else {
                    DeskSurface()
                    if screen == "album" {
                        album(size: geometry.size)
                    } else {
                        desk
                    }
                }
            }
        }
        .foregroundStyle(paper)
        .statusBarHidden()
    }

    private var desk: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 10)
            Text(verbatim: word("game"))
                .font(titleFace(52))
                .tracking(-2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: word("chapter.\(sheet.chapter)"))
                .font(smallFace(13))
                .tracking(2)
                .foregroundStyle(foil)
            Spacer(minLength: 8)
            envelope
                .aspectRatio(1.24, contentMode: .fit)
                .frame(maxWidth: 485, maxHeight: 360)
                .padding(.horizontal, 22)
            Text(verbatim: word(sheet.id))
                .font(titleFace(30))
                .accessibilityIdentifier("desk-title")
            Text(verbatim: word("pull"))
                .font(.callout)
                .foregroundStyle(paper.opacity(0.80))
            Button { openEnvelope() } label: {
                Label(word(save.opened ? "continue" : "open"), systemImage: "envelope.open")
                    .font(.system(.headline, design: .serif))
                    .padding(.horizontal, 26)
                    .frame(minHeight: 48)
            }
            .buttonStyle(SealButton())
            .accessibilityIdentifier("open")
            Spacer(minLength: 6)
            Button { showAlbum() } label: {
                Label(word("album"), systemImage: "book.closed")
                    .font(smallFace(13))
                    .padding(14)
                    .background(lacquer, in: UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("album")
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var envelope: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let lift = envelopeLift
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color(red: 0.78, green: 0.22, blue: 0.15), lacquer,
                                                  Color(red: 0.44, green: 0.10, blue: 0.09)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(foil.opacity(0.65)) }
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 6, y: 14)
                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    var seams = Path()
                    seams.move(to: .zero)
                    seams.addLine(to: CGPoint(x: w * 0.5, y: h * 0.65))
                    seams.addLine(to: CGPoint(x: w, y: 0))
                    seams.move(to: CGPoint(x: 0, y: h))
                    seams.addLine(to: CGPoint(x: w * 0.37, y: h * 0.47))
                    seams.move(to: CGPoint(x: w, y: h))
                    seams.addLine(to: CGPoint(x: w * 0.63, y: h * 0.47))
                    context.stroke(seams, with: .color(ink.opacity(0.48)), lineWidth: 2.4)
                    context.stroke(seams.offsetBy(dx: 0, dy: -1), with: .color(foil.opacity(0.67)), lineWidth: 1)
                    for index in 0..<360 {
                        let x = CGFloat((index * 149 + 17) % 997) / 997 * w
                        let y = CGFloat((index * 283 + 57) % 991) / 991 * h
                        var fibre = Path()
                        fibre.move(to: CGPoint(x: x, y: y))
                        fibre.addLine(to: CGPoint(x: x + CGFloat(index % 6) + 1, y: y + 0.5))
                        context.stroke(fibre, with: .color(foil.opacity(index % 4 == 0 ? 0.20 : 0.08)), lineWidth: 0.6)
                    }
                }
                TigerArt().stroke(foil.opacity(0.83), lineWidth: 1.4)
                    .overlay {
                        Image(systemName: "eye").font(.system(size: w * 0.081, weight: .medium))
                        .foregroundStyle(foil.opacity(0.87))
                    }
                    .frame(width: w * 0.33, height: w * 0.23)
                    .position(x: w * 0.29, y: h * 0.36)
                Image(systemName: "seal.fill")
                    .font(.system(size: w * 0.19))
                    .foregroundStyle(foil)
                    .overlay { Image(systemName: "sparkle").foregroundStyle(lacquer).font(.title) }
                    .shadow(color: ink.opacity(0.36), radius: 4, y: 3)
                    .position(x: w * 0.52, y: h * 0.62)
                Corner()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.98, blue: 0.90), paper,
                                                  Color(red: 0.77, green: 0.60, blue: 0.41)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { Corner().stroke(paper.opacity(0.86), lineWidth: 1.4) }
                    .frame(width: w * 0.29, height: h * 0.35)
                    .rotation3DEffect(.degrees(Double(-12 - lift * 60)), axis: (x: 1, y: 1, z: 0), anchor: .bottomLeading)
                    .offset(x: -lift * w * 0.08, y: lift * h * 0.05)
                    .shadow(color: ink.opacity(0.42), radius: 5 + lift * 15, x: 1, y: 4 + lift * 15)
                    .position(x: w * 0.85, y: h * 0.17)
                Image(systemName: "arrow.down.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ink)
                    .opacity(1 - lift)
                    .position(x: w * 0.88, y: h * 0.16)
            }
            .overlay(alignment: .topTrailing) {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: w * 0.34, height: h * 0.37)
                    .accessibilityLabel(word("pull"))
                    .accessibilityIdentifier("envelope-corner")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { openEnvelope() }
                    .gesture(DragGesture(minimumDistance: 4)
                        .onChanged { envelopeLift = min(1, max(0, ($0.translation.height - $0.translation.width) / 120)) }
                        .onEnded {
                            if $0.translation.height - $0.translation.width > 80 { openEnvelope() }
                            else { withAnimation(.easeOut(duration: 0.22)) { envelopeLift = 0 } }
                        })
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func game(size: CGSize) -> some View {
        let finished = run.won(sheet) && !walking
        return VStack(spacing: 0) {
            HStack(spacing: 7) {
                Button {
                    stopWalk()
                    screen = "desk"
                    envelopeLift = 0
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.forward")
                        .frame(width: 44, height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(word("desk"))
                .accessibilityIdentifier("desk")

                VStack(spacing: 3) {
                    Text(verbatim: word(sheet.id))
                        .font(titleFace(size.width < 540 ? 25 : 33))
                        .lineLimit(1).minimumScaleFactor(0.57)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("sheet-title")
                    HStack(spacing: 8) {
                        Text(verbatim: word("chapter.\(sheet.chapter)"))
                        Text(verbatim: count("folio", number))
                        Text(verbatim: count("folds", run.state.folds))
                            .accessibilityIdentifier("fold-count")
                        Text(verbatim: count("par", sheet.par))
                    }
                    .font(smallFace(size.width < 540 ? 9 : 11))
                    .lineLimit(1).minimumScaleFactor(0.68)
                    .foregroundStyle(ochre)
                }
                .frame(maxWidth: .infinity)

                Button { showAlbum() } label: {
                    Image(systemName: "book.closed")
                        .frame(width: 44, height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(word("album"))
                .accessibilityIdentifier("album")
            }
            .padding(.horizontal, 9)
            .frame(minHeight: size.width < 540 ? 52 : 63)
            .background(alignment: .bottom) {
                Rectangle().fill(ochre.opacity(0.32)).frame(height: 1)
                    .padding(.horizontal, 15)
            }

            SheetView(sheet: sheet, run: run, tiger: displayTiger, beat: tigerBeat, selected: selectedEdge, walking: walking,
                      select: { selectedEdge = $0; notice = "" }, fold: performFold)
                .id(sheet.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("active-sheet")

            if finished {
                printControls
            } else {
                playControls
            }
        }
        .padding(.bottom, 4)
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusKey: String {
        if !notice.isEmpty { return notice }
        if tigerBeat?.kind == .probe { return "check.bridge" }
        if walking { return "walking" }
        if run.state.released { return sheet.id == "stream" ? "stream.stop" : "stop" }
        if run.aligned(sheet) { return "aligned" }
        return "clue.\(sheet.id)"
    }

    private var playControls: some View {
        VStack(spacing: 2) {
            Text(verbatim: word(statusKey))
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(statusKey == "aligned" ? lacquer : ink)
                .frame(maxWidth: .infinity, minHeight: 29)
                .accessibilityIdentifier("sheet-status")

            HStack(spacing: 5) {
                utility("undo", icon: "arrow.uturn.backward", enabled: !run.undo.isEmpty && !walking, action: undo)
                utility("hint", icon: "lightbulb", enabled: !walking, action: hint)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    arrow(-1)
                    arrow(1)
                }
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityHint(selectedEdge.map { word("edge.\(sheet.panels[$0].id)") } ?? word("choose"))
                Spacer(minLength: 0)
                Button(action: release) {
                    Label(word("release"), systemImage: "seal.fill")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 45)
                }
                .buttonStyle(SealButton(bright: run.aligned(sheet) && !run.state.released))
                .disabled(run.state.released || walking)
                .opacity(run.state.released ? 0.64 : 1)
                .accessibilityIdentifier("release")
            }
        }
        .padding(.horizontal, 12)
        .background(alignment: .top) {
            Rectangle().fill(ochre.opacity(0.32)).frame(height: 1)
                .padding(.horizontal, 15)
        }
    }

    private var printControls: some View {
        let inPar = run.state.folds <= sheet.par
        return VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "seal.fill").accessibilityHidden(true)
                Text(verbatim: word(number == campaign.count ? "home.done" : "print"))
                    .accessibilityIdentifier("print")
            }
            .font(titleFace(23)).foregroundStyle(lacquer)
            HStack(spacing: 9) {
                Text(verbatim: word(inPar ? "gold.print" : "improve"))
                    .font(.caption).multilineTextAlignment(.center)
                Text(verbatim: count("best", save.prints[sheet.id]?.best ?? run.state.folds))
                    .font(smallFace(10)).foregroundStyle(ochre)
                    .accessibilityIdentifier("best")
            }
            HStack(spacing: 6) {
                utility("undo", icon: "arrow.uturn.backward", enabled: !run.undo.isEmpty, action: undo)
                utility("replay", icon: "arrow.clockwise", enabled: true) { start(sheet) }
                Spacer(minLength: 0)
                Button {
                    if number < campaign.count { start(campaign[number]) } else { showAlbum() }
                } label: {
                    Text(verbatim: word(number < campaign.count ? "next" : "album"))
                        .font(.system(.headline, design: .serif)).padding(.horizontal, 15).frame(minHeight: 45)
                }
                .buttonStyle(SealButton())
                .accessibilityIdentifier("next")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 3)
        .background(alignment: .top) {
            Rectangle().fill(ochre.opacity(0.32)).frame(height: 1)
                .padding(.horizontal, 15)
        }
    }

    private func arrow(_ delta: Int) -> some View {
        let pose = selectedEdge.map { run.state.poses[$0] + delta } ?? 0
        let enabled = selectedEdge.map { run.canFold(sheet, $0, pose) } == true && !walking
        let key = delta < 0 ? "left" : "right"
        return Button {
            if let selectedEdge { performFold(selectedEdge, pose) }
        } label: {
            Image(systemName: delta < 0 ? "arrow.left" : "arrow.right")
                .environment(\.layoutDirection, .leftToRight)
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(ochre.opacity(enabled ? 0.18 : 0.07), in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.48)
        .disabled(!enabled)
        .accessibilityLabel(word(key))
        .accessibilityIdentifier("fold-\(key)")
    }

    private func utility(_ key: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 16))
                Text(verbatim: word(key)).font(smallFace(10)).lineLimit(1)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.45)
        .disabled(!enabled)
        .accessibilityIdentifier(key)
    }

    private func album(size: CGSize) -> some View {
        let selected = campaign.first { $0.id == selectedID } ?? sheet
        let wide = size.width >= 670
        let tall = size.height > size.width
        let cardHeight = wide ? min(size.width * (tall ? 0.35 : 0.24),
                                    (size.height - (tall ? 590 : 240)) / 2) : 91
        return VStack(spacing: 7) {
            HStack(spacing: 8) {
                Button {
                    screen = "desk"
                    envelopeLift = 0
                } label: {
                    Label(word("desk"), systemImage: "arrow.uturn.backward")
                        .font(smallFace(12)).frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("album-desk")
                Spacer(minLength: 0)
                Text(verbatim: word("album"))
                    .font(titleFace(wide ? 38 : 31))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Text(verbatim: count("collected", save.prints.count))
                    .font(smallFace()).foregroundStyle(foil)
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
            .padding(.horizontal, 5)
            HStack(spacing: 4) {
                ForEach(0..<4) { index in
                    Button {
                        chapter = index
                        selectedID = campaign[index * 4].id
                    } label: {
                        Text(verbatim: word("chapter.\(index)"))
                            .font(.system(size: wide ? 16 : 13, weight: chapter == index ? .bold : .regular, design: .serif))
                            .minimumScaleFactor(0.65)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(chapter == index ? lacquer : paper.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chapter-\(index)")
                    .accessibilityAddTraits(chapter == index ? .isSelected : [])
                }
            }
            ScrollView {
                if wide && !tall {
                    HStack(alignment: .center, spacing: 14) {
                        albumSpread(height: max(110, cardHeight))
                            .frame(width: size.width * 0.61)
                        albumDetail(selected, previewHeight: min(size.width * 0.325, size.height * 0.58), beside: false)
                    }
                    .frame(minHeight: max(0, size.height - 113), alignment: .center)
                    .padding(.bottom, 8)
                } else {
                    VStack(spacing: wide ? 13 : 8) {
                        albumSpread(height: max(91, cardHeight))
                        albumDetail(selected, previewHeight: wide ? min(340, size.height * 0.25) : 0, beside: wide)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(.horizontal, wide ? 15 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func albumSpread(height: CGFloat) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 12) {
            ForEach(campaign.filter { $0.chapter == chapter }) { entry in
                Button {
                    selectedID = entry.id
                } label: {
                    VStack(spacing: 5) {
                        preview(entry, muted: save.prints[entry.id] == nil)
                            .frame(height: height)
                        Text(verbatim: word(entry.id))
                            .font(titleFace(16)).lineLimit(2).multilineTextAlignment(.center)
                        Text(verbatim: albumStatus(entry))
                            .font(smallFace(9)).lineLimit(1).minimumScaleFactor(0.65)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .background(selectedID == entry.id ? foil.opacity(0.27) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("folio-\(entry.id)")
            }
        }
        .padding(10)
        .foregroundStyle(ink)
        .background(paper.gradient, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            VStack(spacing: 0) {
                ForEach(0..<9) { _ in
                    Capsule().fill(ochre.opacity(0.55)).frame(width: 2, height: 8)
                    Spacer(minLength: 1)
                }
            }
            .padding(.vertical, 10)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func albumDetail(_ entry: Sheet, previewHeight: CGFloat, beside: Bool) -> some View {
        Group {
            if beside {
                HStack(spacing: 20) {
                    preview(entry, muted: save.prints[entry.id] == nil)
                        .frame(height: previewHeight)
                        .frame(maxWidth: .infinity)
                    albumEntry(entry)
                }
            } else {
                VStack(spacing: 10) {
                    if previewHeight > 0 {
                        preview(entry, muted: save.prints[entry.id] == nil).frame(height: previewHeight)
                    }
                    albumEntry(entry)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(paper.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func albumEntry(_ entry: Sheet) -> some View {
        VStack(spacing: 7) {
            Text(verbatim: word(entry.id)).font(titleFace(25)).multilineTextAlignment(.center)
            Text(verbatim: albumStatus(entry)).font(smallFace()).foregroundStyle(foil)
            if unlocked(entry) {
                Button {
                    if entry.id == sheet.id && !run.won(sheet) && save.prints[entry.id] == nil {
                        openEnvelope()
                    } else {
                        start(entry)
                    }
                } label: {
                    Text(verbatim: word(save.prints[entry.id] != nil ? "replay" : "open"))
                        .padding(.horizontal, 23).frame(minHeight: 46)
                }
                .buttonStyle(SealButton())
                .accessibilityIdentifier("album-play")
            } else {
                let index = campaign.firstIndex { $0.id == entry.id } ?? 0
                Text(verbatim: String(format: word("unlock"), word(campaign[max(0, index - 1)].id)))
                    .font(.callout).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func preview(_ entry: Sheet, muted: Bool) -> some View {
        var printRun = Attempt(entry)
        if let impression = save.prints[entry.id] {
            printRun.state.poses = impression.poses
            printRun.state.layers = impression.layers
        }
        return PrintThumbnail(sheet: entry, run: printRun, printed: !muted)
            .aspectRatio(0.91, contentMode: .fit)
            .saturation(muted ? 0.32 : 0.94)
            .opacity(muted ? 0.66 : 1)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityHidden(true)
    }

    private func albumStatus(_ entry: Sheet) -> String {
        if let impression = save.prints[entry.id] {
            return count(impression.inPar ? "best.gold" : "best", impression.best)
        }
        return word(unlocked(entry) ? "available" : "locked")
    }

    private func unlocked(_ entry: Sheet) -> Bool {
        let index = campaign.firstIndex { $0.id == entry.id } ?? 0
        return index == 0 || save.prints[campaign[index - 1].id] != nil
    }

    private func showAlbum() {
        stopWalk()
        chapter = sheet.chapter
        selectedID = sheet.id
        screen = "album"
    }

    private func openEnvelope() {
        envelopeLift = 0
        if !save.opened { sound.play("paper") }
        save.opened = true
        screen = "sheet"
        persist()
    }

    private func start(_ entry: Sheet) {
        stopWalk()
        save.open(entry)
        selectedEdge = nil
        notice = ""
        displayTiger = 0
        screen = "sheet"
        persist()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: storage.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(save).write(to: storage, options: .atomic)
        } catch {
            notice = "save.error"
        }
    }

    private func performFold(_ index: Int, _ pose: Int) {
        guard !walking else { return }
        let oldTiger = run.state.tiger
        var next = save.attempt
        guard next.fold(sheet, index, pose) else { return }
        withAnimation(reduceMotion ? nil : .timingCurve(0.28, 0.02, 0.33, 1, duration: 0.52)) { save.attempt = next }
        selectedEdge = index
        notice = ""
        sound.play("paper")
        finishMove(from: oldTiger, settingPaper: true)
    }

    private func release() {
        guard !walking else { return }
        let oldTiger = run.state.tiger
        guard save.attempt.release(sheet) else {
            notice = "seal.incomplete"
            return
        }
        notice = ""
        sound.play("seal")
        finishMove(from: oldTiger)
    }

    private func finishMove(from previous: Int, settingPaper: Bool = false) {
        save.record(sheet)
        persist()
        let target = run.state.tiger
        guard target > previous else { return }
        walking = true
        let checkBridge = settingPaper && sheet.gaps.contains(previous) && run.spans(sheet, previous)
        walkTask = Task { @MainActor in
            if reduceMotion {
                for next in (previous + 1)...target {
                    guard !Task.isCancelled else { return }
                    displayTiger = next
                    try? await Task.sleep(for: .milliseconds(140))
                }
            } else {
                if settingPaper {
                    try? await Task.sleep(for: .milliseconds(510))
                    guard !Task.isCancelled else { return }
                } else if previous == 0 {
                    guard await showBeat(.rise, at: previous, duration: 0.42) else { return }
                }
                if checkBridge {
                    guard await showBeat(.probe, at: previous, duration: 0.70, taps: [0.49],
                                         soundName: "bridge") else { return }
                }
                for next in (previous + 1)...target {
                    let edge = next - 1
                    let a = sheet.points[edge]
                    let b = sheet.points[next]
                    let distance = hypot(b[0] - a[0], (b[1] - a[1]) * 1.32)
                    let cycles = max(1, Int(ceil(distance / 0.169)))
                    let taps = (1..<(cycles * 4)).map { Double($0) / Double(cycles * 4) }
                    guard await showBeat(.stride, at: edge, duration: 0.57 * Double(cycles), cycles: cycles,
                                         taps: taps, soundName: "paw") else { return }
                    displayTiger = next
                }
                if !run.won(sheet) {
                    guard await showBeat(.brake, at: target, duration: 0.33) else { return }
                }
            }
            guard !Task.isCancelled else { return }
            tigerBeat = nil
            walking = false
            if run.won(sheet) { sound.play("seal") }
        }
    }

    private func showBeat(_ kind: TigerBeatKind, at node: Int, duration: TimeInterval,
                          cycles: Int = 1, taps: [Double] = [], soundName: String = "paw") async -> Bool {
        tigerBeat = TigerBeat(kind: kind, node: node, start: Date(), duration: duration, cycles: cycles)
        var elapsed = 0.0
        for tap in taps {
            try? await Task.sleep(for: .seconds((tap - elapsed) * duration))
            guard !Task.isCancelled else { return false }
            sound.play(soundName, tactile: false)
            elapsed = tap
        }
        try? await Task.sleep(for: .seconds((1 - elapsed) * duration))
        return !Task.isCancelled
    }

    private func stopWalk() {
        walkTask?.cancel()
        tigerBeat = nil
        walking = false
        displayTiger = run.state.tiger
    }

    private func undo() {
        stopWalk()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) {
            save.attempt.stepBack()
            displayTiger = run.state.tiger
        }
        if let selectedEdge, !run.accessible(sheet, selectedEdge) { self.selectedEdge = nil }
        notice = ""
        persist()
    }

    private func hint() {
        if run.aligned(sheet) && !run.state.released {
            notice = "hint.release"
            return
        }
        if let first = quickestPath(sheet, from: run)?.first {
            selectedEdge = first.panel
            notice = "hint.edge"
        } else {
            notice = "hint.undo"
        }
    }
}

struct SealButton: ButtonStyle {
    var bright = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(bright ? ink : paper)
            .background((bright ? foil : lacquer).gradient, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(paper.opacity(0.26)) }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct Corner: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX * 0.83, y: rect.maxY * 1.08))
        }
    }
}

struct DeskSurface: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.30, green: 0.20, blue: 0.17), charcoal, Color(red: 0.21, green: 0.12, blue: 0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                for i in 0..<185 {
                    let y = CGFloat(i) * size.height / 185
                    var grain = Path()
                    grain.move(to: CGPoint(x: 0, y: y))
                    grain.addQuadCurve(to: CGPoint(x: size.width, y: y + CGFloat(i % 7) - 4),
                                       control: CGPoint(x: size.width * 0.5, y: y + CGFloat(i % 17) - 8))
                    context.stroke(grain, with: .color((i % 8 == 0 ? foil : paper).opacity(i % 8 == 0 ? 0.10 : 0.022)), lineWidth: 0.65)
                }
                let edge = Path(roundedRect: CGRect(x: 7, y: 7, width: size.width - 14, height: size.height - 14), cornerRadius: 16)
                context.stroke(edge, with: .color(foil.opacity(0.12)), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
