//
//  CalculatorModel.swift
//  hexa
//
//  Created by Kushagra Srivastava on 1/28/26.
//

import Foundation

enum Base: String, CaseIterable, Identifiable {
    case hex = "HEX"
    case dec = "DEC"
    case oct = "OCT"
    case bin = "BIN"
    
    var id: Self { self }
    var radix: Int {
        switch self {
        case .bin: 2
        case .oct: 8
        case .dec: 10
        case .hex: 16
        }
    }
    var prefix: String {
        switch self {
        case .hex: "0x"
        case .dec: ""
        case .oct: "0o"
        case .bin: "0b"
        }
    }
}

enum BitWidth: Int, CaseIterable, Identifiable {
    case eight = 8
    case sixteen = 16
    case thirtyTwo = 32
    case sixtyFour = 64
    
    var id: Int { rawValue }
    var label: String { "\(rawValue) bit" }
    var mask: UInt64 {
        rawValue == 64 ? UInt64.max : (1 << rawValue) - 1
    }
}

enum SignMode: String, CaseIterable, Identifiable {
    case signed = "Signed"
    case unsigned = "Unsigned"
    var id: Self { self }
}

enum Operation {
    case add, subtract, multiply, divide, mod
    case and, or, xor, nand, nor, xnor
    case shiftLeft, shiftRight, rotateLeft, rotateRight
    
    func apply(_ a: UInt64, _ b: UInt64, width: BitWidth) -> UInt64 {
        let mask = width.mask
        let result: UInt64
        switch self {
        case .add:      result = a &+ b
        case .subtract: result = a &- b
        case .multiply: result = a &* b
        case .divide:   result = b == 0 ? 0 : a / b
        case .mod:      result = b == 0 ? 0 : a % b
        case .and:      result = a & b
        case .or:       result = a | b
        case .xor:      result = a ^ b
        case .nand:     result = ~(a & b)
        case .nor:      result = ~(a | b)
        case .xnor:     result = ~(a ^ b)
        case .shiftLeft:
            let shift = b % UInt64(width.rawValue)
            result = a << shift
        case .shiftRight:
            let shift = b % UInt64(width.rawValue)
            result = a >> shift
        case .rotateLeft:
            let shift = Int(b % UInt64(width.rawValue))
            let w = width.rawValue
            result = ((a << shift) | (a >> (w - shift)))
        case .rotateRight:
            let shift = Int(b % UInt64(width.rawValue))
            let w = width.rawValue
            result = ((a >> shift) | (a << (w - shift)))
        }
        return result & mask
    }
}

struct CalculatorModel {
    var currentValue: UInt64 = 0
    var storedValue: UInt64 = 0
    var pendingOperation: Operation? = nil
    var inputBuffer: String = ""
    var base: Base = .hex
    var bitWidth: BitWidth = .sixtyFour
    var signMode: SignMode = .signed
    var memory: UInt64 = 0
    var hasMemory: Bool = false
    
    var displayValue: UInt64 {
        currentValue & bitWidth.mask
    }
    
    var signedValue: Int64 {
        let masked = displayValue
        let signBit = UInt64(1) << (bitWidth.rawValue - 1)
        if masked & signBit != 0 {
            // Negative: sign extend
            return Int64(bitPattern: masked | ~bitWidth.mask)
        }
        return Int64(masked)
    }
    
    mutating func inputDigit(_ digit: String) {
        inputBuffer += digit
        if let parsed = UInt64(inputBuffer, radix: base.radix) {
            currentValue = parsed & bitWidth.mask
        }
    }
    
    mutating func clear() {
        currentValue = 0
        inputBuffer = ""
    }
    
    mutating func clearAll() {
        clear()
        storedValue = 0
        pendingOperation = nil
    }
    
    mutating func backspace() {
        if !inputBuffer.isEmpty {
            inputBuffer.removeLast()
            if inputBuffer.isEmpty {
                currentValue = 0
            } else if let parsed = UInt64(inputBuffer, radix: base.radix) {
                currentValue = parsed & bitWidth.mask
            }
        }
    }
    
    mutating func setOperation(_ op: Operation) {
        if pendingOperation != nil {
            evaluate()
        }
        storedValue = currentValue
        pendingOperation = op
        inputBuffer = ""
    }
    
    mutating func evaluate() {
        guard let op = pendingOperation else { return }
        currentValue = op.apply(storedValue, currentValue, width: bitWidth)
        pendingOperation = nil
        storedValue = 0
        inputBuffer = ""
    }
    
    mutating func toggleSign() {
        currentValue = (~currentValue &+ 1) & bitWidth.mask
        inputBuffer = ""
    }
    
    mutating func bitwiseNot() {
        currentValue = (~currentValue) & bitWidth.mask
        inputBuffer = ""
    }
    
    mutating func toggleBit(at index: Int) {
        currentValue ^= (1 << index)
        inputBuffer = ""
    }
    
    // Memory operations
    mutating func memoryClear() {
        memory = 0
        hasMemory = false
    }
    
    mutating func memoryRecall() {
        currentValue = memory & bitWidth.mask
        inputBuffer = ""
    }
    
    mutating func memoryAdd() {
        memory = (memory &+ currentValue) & bitWidth.mask
        hasMemory = true
    }
    
    mutating func memoryStore() {
        memory = currentValue
        hasMemory = true
    }
    
    func formatted(_ value: UInt64, base: Base) -> String {
        let masked = value & bitWidth.mask
        switch base {
        case .hex: return String(masked, radix: 16, uppercase: true)
        case .dec:
            if signMode == .signed {
                return "\(signedValue)"
            }
            return "\(masked)"
        case .oct: return String(masked, radix: 8)
        case .bin: return String(masked, radix: 2)
        }
    }
}
