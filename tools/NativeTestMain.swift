import Foundation

@main struct NativeTestMain {
    static func main() {
        let argument = CommandLine.arguments.dropFirst().first ?? "status"
        if argument == "--self-test" { selfTest(); return }
        print(runCommand(argument))
    }
}
