import Foundation

@main
struct StreamPilot {
    static func main() throws {
        let json = try Data(contentsOf: URL(fileURLWithPath: "QA/stream-pilot.json"))
        let sheet = try JSONDecoder().decode(Sheet.self, from: json)
        var run = Attempt(sheet)
        precondition(!run.release(sheet))
        precondition(run.fold(sheet, 0, 1))
        precondition(run.release(sheet))
        precondition(run.state.tiger == 1 && !run.spans(sheet, 1))
        let bank = run.state
        precondition(run.fold(sheet, 1, 1))
        precondition(run.state.tiger == 1)
        run.stepBack()
        precondition(run.state == bank)
        precondition(run.fold(sheet, 1, -1))
        precondition(run.won(sheet))
        run.stepBack()
        precondition(run.state == bank && !run.spans(sheet, 1))
        print("PASS stream pilot: body releases, east tail misses, west tail bridges, Undo restores prior poses/layers/tiger.")
    }
}
