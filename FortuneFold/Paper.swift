import Foundation

struct Face: Codable, Equatable {
    var mark: String?
    var span: Int?
}

struct Panel: Codable, Identifiable {
    let id: String
    let faces: [Face] // Left, flat, right.
    var cover: String?
    var window: Bool?
    var starts: Int?
}

struct Sheet: Codable, Identifiable {
    let id: String
    let chapter: Int
    let par: Int
    let scene: Int
    let points: [[Double]]
    let panels: [Panel] // Bottom to top.
    let marks: [String]
    let gaps: [Int]
    var shortGap: Int?
    var shortMark: String?
}

struct FoldState: Codable, Equatable {
    var poses: [Int]
    var layers: [Int]
    var tiger = 0
    var released = false
    var folds = 0
}

struct Attempt: Codable, Equatable {
    var state: FoldState
    var undo: [FoldState] = []

    init(_ sheet: Sheet) {
        state = FoldState(poses: sheet.panels.map { $0.starts ?? 0 },
                          layers: Array(sheet.panels.indices))
    }

    func face(_ sheet: Sheet, _ panel: Int) -> Face {
        sheet.panels[panel].faces[state.poses[panel] + 1]
    }

    func cover(_ sheet: Sheet, _ panel: Int) -> Int? {
        guard let depth = state.layers.firstIndex(of: panel) else { return nil }
        return state.layers.dropFirst(depth + 1).reversed().first {
            sheet.panels[$0].cover == sheet.panels[panel].id && state.poses[$0] == 0 && state.poses[panel] == 0
        }
    }

    func accessible(_ sheet: Sheet, _ panel: Int) -> Bool {
        cover(sheet, panel) == nil
    }

    func visible(_ sheet: Sheet, _ panel: Int) -> Bool {
        guard let top = cover(sheet, panel) else { return true }
        return sheet.panels[top].window == true && visible(sheet, top)
    }

    func marks(_ sheet: Sheet) -> Set<String> {
        Set(sheet.panels.indices.compactMap { visible(sheet, $0) ? face(sheet, $0).mark : nil })
    }

    func aligned(_ sheet: Sheet) -> Bool {
        Set(sheet.marks).isSubset(of: marks(sheet))
    }

    func spans(_ sheet: Sheet, _ edge: Int) -> Bool {
        sheet.panels.indices.contains {
            accessible(sheet, $0) && face(sheet, $0).span == edge
        }
    }

    func canFold(_ sheet: Sheet, _ panel: Int, _ pose: Int) -> Bool {
        sheet.panels.indices.contains(panel) && (-1...1).contains(pose)
            && accessible(sheet, panel) && state.poses[panel] != pose
            && abs(state.poses[panel] - pose) == 1 && !won(sheet)
    }

    mutating func fold(_ sheet: Sheet, _ panel: Int, _ pose: Int) -> Bool {
        guard canFold(sheet, panel, pose) else { return false }
        undo.append(state)
        state.poses[panel] = pose
        state.layers.removeAll { $0 == panel }
        if pose == 0, let hidden = sheet.panels[panel].cover,
           let lower = sheet.panels.firstIndex(where: { $0.id == hidden }),
           let depth = state.layers.firstIndex(of: lower) {
            state.layers.insert(panel, at: depth + 1)
        } else {
            state.layers.append(panel)
        }
        state.folds += 1
        if state.released { walk(sheet) }
        return true
    }

    mutating func release(_ sheet: Sheet) -> Bool {
        guard !state.released, aligned(sheet) else { return false }
        undo.append(state)
        state.released = true
        walk(sheet)
        return true
    }

    mutating func walk(_ sheet: Sheet) {
        while state.tiger < sheet.points.count - 1 {
            let edge = state.tiger
            if sheet.gaps.contains(edge) && !spans(sheet, edge) {
                let shortOpen = sheet.shortGap == edge &&
                    sheet.shortMark.map { marks(sheet).contains($0) } == true
                if !shortOpen { return }
            }
            state.tiger += 1
        }
    }

    func won(_ sheet: Sheet) -> Bool {
        state.tiger == sheet.points.count - 1
    }

    mutating func stepBack() {
        if let previous = undo.popLast() { state = previous }
    }
}

struct FoldMove {
    var panel: Int
    var pose: Int
}

struct SearchKey: Hashable {
    let poses: [Int]
    let layers: [Int]
    let tiger: Int
    let released: Bool

    init(_ attempt: Attempt) {
        poses = attempt.state.poses
        layers = attempt.state.layers
        tiger = attempt.state.tiger
        released = attempt.state.released
    }
}

// Release has no fold cost. Expand it before considering the next fold.
func quickestPath(_ sheet: Sheet, from start: Attempt) -> [FoldMove]? {
    var frontier: [(Attempt, [FoldMove])] = [(start, [])]
    var visited: Set<SearchKey> = []
    while !frontier.isEmpty {
        var next: [(Attempt, [FoldMove])] = []
        for (run, moves) in frontier {
            var released = run
            let didRelease = released.release(sheet)
            for candidate in didRelease ? [run, released] : [run] {
                guard visited.insert(SearchKey(candidate)).inserted else { continue }
                if candidate.won(sheet) { return moves }
                for panel in sheet.panels.indices {
                    for delta in [-1, 1] {
                        let pose = candidate.state.poses[panel] + delta
                        var folded = candidate
                        if folded.fold(sheet, panel, pose) {
                            folded.undo = []
                            next.append((folded, moves + [FoldMove(panel: panel, pose: pose)]))
                        }
                    }
                }
            }
        }
        frontier = next
    }
    return nil
}

struct PrintRecord: Codable {
    var best: Int
    var inPar: Bool
    var poses: [Int]
    var layers: [Int]
}

struct DeskSave: Codable {
    var sheetID: String
    var opened = false
    var attempt: Attempt
    var prints: [String: PrintRecord] = [:]

    init(sheet: Sheet) {
        sheetID = sheet.id
        attempt = Attempt(sheet)
    }

    mutating func open(_ sheet: Sheet) {
        sheetID = sheet.id
        opened = true
        attempt = Attempt(sheet)
    }

    mutating func record(_ sheet: Sheet) {
        guard attempt.won(sheet) else { return }
        let state = attempt.state
        guard prints[sheet.id].map({ state.folds < $0.best }) ?? true else { return }
        prints[sheet.id] = PrintRecord(best: state.folds, inPar: state.folds <= sheet.par,
                                      poses: state.poses, layers: state.layers)
    }
}

func readCampaign(from url: URL) throws -> [Sheet] {
    try JSONDecoder().decode([Sheet].self, from: Data(contentsOf: url))
}
