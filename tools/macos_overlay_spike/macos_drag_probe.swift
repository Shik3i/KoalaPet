import ApplicationServices
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 5,
      let startX = Double(CommandLine.arguments[1]),
      let startY = Double(CommandLine.arguments[2]),
      let endX = Double(CommandLine.arguments[3]),
      let endY = Double(CommandLine.arguments[4]) else {
    FileHandle.standardError.write(Data("usage: swift macos_drag_probe.swift START_X START_Y END_X END_Y\n".utf8))
    exit(2)
}

let start = CGPoint(x: startX, y: startY)
let end = CGPoint(x: endX, y: endY)
let steps = 20
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: start, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(100_000)
CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left)?.post(tap: .cghidEventTap)
for index in 1...steps {
    let fraction = CGFloat(index) / CGFloat(steps)
    let point = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(20_000)
}
CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left)?.post(tap: .cghidEventTap)
print("{\"accessibility_trusted\":\(AXIsProcessTrusted()),\"drag_start\":[\(startX),\(startY)],\"drag_end\":[\(endX),\(endY)]}")
