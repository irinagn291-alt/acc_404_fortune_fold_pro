import Foundation

@main
struct VerifyCampaign {
    static func main() throws {
        let campaign = try readCampaign(from: URL(fileURLWithPath: "FortuneFold/Resources/Campaign.json"))
        let file = try Data(contentsOf: URL(fileURLWithPath: "QA/solutions.json"))
        let solutions = try JSONDecoder().decode([String: [String]].self, from: file)
        precondition(campaign.count == 16 && Set(campaign.map(\.id)).count == 16)
        precondition((0...3).allSatisfy { number in campaign.filter { $0.chapter == number }.count == 4 })
        for sheet in campaign {
            var run = Attempt(sheet)
            for action in solutions[sheet.id]! {
                if action == "go" {
                    precondition(run.release(sheet), "\(sheet.id): release")
                } else {
                    let id = String(action.dropLast())
                    let index = sheet.panels.firstIndex { $0.id == id }!
                    let pose = action.last == "+" ? 1 : (action.last == "-" ? -1 : 0)
                    precondition(run.fold(sheet, index, pose), "\(sheet.id): \(action)")
                }
            }
            precondition(run.won(sheet), "\(sheet.id): gate")
            precondition(run.state.folds == sheet.par, "\(sheet.id): par vs author solution")
            let minimum = quickestPath(sheet, from: Attempt(sheet))?.count
            print("PASS \(sheet.id): \(run.state.folds) folds, par \(sheet.par), minimum \(minimum ?? -1); \(solutions[sheet.id]!.joined(separator: " "))")
            precondition(minimum == sheet.par, "\(sheet.id): minimum")
        }
        var save = DeskSave(sheet: campaign[0])
        let sheet = campaign[0]
        precondition(save.attempt.fold(sheet, 0, 1))
        let midFold = save.attempt
        let copy = try JSONDecoder().decode(DeskSave.self, from: JSONEncoder().encode(save))
        precondition(copy.attempt == midFold)
        precondition(save.attempt.fold(sheet, 1, -1) && save.attempt.release(sheet))
        save.record(sheet)
        save.attempt.state.folds = 6
        save.record(sheet)
        precondition(save.prints.count == 1 && save.prints[sheet.id]?.best == 2 && save.prints[sheet.id]?.inPar == true)
        print("PASS save round trip preserves poses, layers, tiger and Undo; a slower completion preserves the earlier print.")
    }
}
