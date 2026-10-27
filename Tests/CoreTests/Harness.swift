// Dependency-free test harness (stdlib only).
//
// Runs with either:
//   swift run CoreTests        (SwiftPM, on a healthy toolchain)
//   ./scripts/test-core.sh     (direct swiftc; used in this repo)

var _total = 0
var _failed = 0

func suite(_ name: String) {
    print("\n[\(name)]")
}

func check(_ condition: Bool, _ label: String, file: String = #file, line: Int = #line) {
    _total += 1
    if condition {
        print("  ok   \(label)")
    } else {
        _failed += 1
        print("  FAIL \(label)  (\(file):\(line))")
    }
}

func equal<T: Equatable>(_ actual: T, _ expected: T, _ label: String, file: String = #file, line: Int = #line) {
    if actual == expected {
        check(true, label, file: file, line: line)
    } else {
        check(false, "\(label) — expected \(expected), got \(actual)", file: file, line: line)
    }
}

func equalOptional<T: Equatable>(_ actual: T?, _ expected: T?, _ label: String, file: String = #file, line: Int = #line) {
    if actual == expected {
        check(true, label, file: file, line: line)
    } else {
        check(false, "\(label) — expected \(String(describing: expected)), got \(String(describing: actual))", file: file, line: line)
    }
}

func finish() {
    print("\n\(_total) checks, \(_failed) failed")
    if _failed > 0 {
        fatalError("\(_failed) test(s) failed")
    }
    print("ALL PASS")
}
