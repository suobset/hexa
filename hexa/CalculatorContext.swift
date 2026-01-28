//
//  CalculatorContext.swift
//  hexa
//
//  Created by Kushagra Srivastava on 1/28/26.
//


import SwiftUI

@Observable
class CalculatorContext {
    var model = CalculatorModel()
    
    // Convenience accessors
    var displayValue: UInt64 { model.displayValue }
    var base: Base {
        get { model.base }
        set { model.base = newValue; model.inputBuffer = "" }
    }
    var bitWidth: BitWidth {
        get { model.bitWidth }
        set {
            model.bitWidth = newValue
            model.currentValue = model.currentValue & newValue.mask
        }
    }
    var signMode: SignMode {
        get { model.signMode }
        set { model.signMode = newValue }
    }
    var hasMemory: Bool { model.hasMemory }
    var hasPendingOp: Bool { model.pendingOperation != nil }
    
    func digit(_ d: String) { model.inputDigit(d) }
    func operation(_ op: Operation) { model.setOperation(op) }
    func equals() { model.evaluate() }
    func clear() { model.clear() }
    func clearAll() { model.clearAll() }
    func backspace() { model.backspace() }
    func toggleSign() { model.toggleSign() }
    func bitwiseNot() { model.bitwiseNot() }
    func toggleBit(at i: Int) { model.toggleBit(at: i) }
    
    func mc() { model.memoryClear() }
    func mr() { model.memoryRecall() }
    func mPlus() { model.memoryAdd() }
    func ms() { model.memoryStore() }
    
    func formatted(base: Base) -> String {
        model.formatted(displayValue, base: base)
    }
    
    func formattedGrouped(base: Base) -> String {
        let raw = formatted(base: base)
        switch base {
        case .hex:
            return groupString(raw, every: 4)
        case .bin:
            let padded = String(repeating: "0", count: (4 - raw.count % 4) % 4) + raw
            return groupString(padded, every: 4)
        case .dec, .oct:
            return raw
        }
    }
    
    private func groupString(_ s: String, every n: Int) -> String {
        var result = ""
        for (i, c) in s.enumerated() {
            if i > 0 && (s.count - i) % n == 0 { result += " " }
            result.append(c)
        }
        return result
    }
    
    func copyToClipboard(base: Base) {
        let value = formatted(base: base)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
    
    func isDigitEnabled(_ digit: String) -> Bool {
        guard let d = Int(digit, radix: 16) else { return false }
        return d < base.radix
    }
}
