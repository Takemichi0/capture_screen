import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: ScreenshotCaptureAgent <capture-script>\n", stderr)
    exit(2)
}

let captureScript = CommandLine.arguments[1]
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/bash")
process.arguments = [captureScript]

do {
    try process.run()
    process.waitUntilExit()
    exit(process.terminationStatus)
} catch {
    fputs("Could not run capture script: \(error)\n", stderr)
    exit(1)
}
