//
//  CalculatorView.swift
//  hexa
//
//  Created by Kushagra Srivastava on 1/28/26.
//

import SwiftUI

struct CalculatorView: View {
    @State private var ctx = CalculatorContext()
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Display Area
            DisplayArea(ctx: ctx, inputText: $inputText, inputFocused: $inputFocused)
            
            Divider().padding(.horizontal)
            
            // MARK: - Live Conversions
            ConversionsPanel(ctx: ctx)
            
            Divider().padding(.horizontal)
            
            // MARK: - Controls & Keypad
            ControlsArea(ctx: ctx, inputText: $inputText)
            
        }
        .padding(.vertical, 12)
        .frame(width: 340)
        .background(.background)
        .onChange(of: inputText) { _, newValue in
            parseInput(newValue)
        }
        .onAppear { inputFocused = true }
    }
    
    private func parseInput(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else {
            ctx.model.currentValue = 0
            return
        }
        
        // Try to evaluate as expression first
        if let result = evaluateExpression(cleaned) {
            ctx.model.currentValue = result & ctx.bitWidth.mask
            return
        }
        
        // Fall back to single value parsing
        var value: UInt64? = nil
        
        // Auto-detect prefixes
        if cleaned.hasPrefix("0x") {
            value = UInt64(cleaned.dropFirst(2), radix: 16)
        } else if cleaned.hasPrefix("0b") {
            value = UInt64(cleaned.dropFirst(2), radix: 2)
        } else if cleaned.hasPrefix("0o") {
            value = UInt64(cleaned.dropFirst(2), radix: 8)
        } else {
            value = UInt64(cleaned, radix: ctx.base.radix)
        }
        
        if let v = value {
            ctx.model.currentValue = v & ctx.bitWidth.mask
        }
    }
    
    private func evaluateExpression(_ expr: String) -> UInt64? {
        // Tokenize the expression
        var tokens: [String] = []
        var current = ""
        var i = expr.startIndex
        
        while i < expr.endIndex {
            let c = expr[i]
            
            // Check for two-char operators
            if i < expr.index(before: expr.endIndex) {
                let next = expr[expr.index(after: i)]
                let twoChar = String(c) + String(next)
                if twoChar == "<<" || twoChar == ">>" {
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                    tokens.append(twoChar)
                    i = expr.index(i, offsetBy: 2)
                    continue
                }
            }
            
            // Check for prefix (0x, 0b, 0o)
            if (c == "x" || c == "b" || c == "o") && current == "0" {
                current.append(c)
                i = expr.index(after: i)
                continue
            }
            
            // Single char operators
            if "+-*/%&|^".contains(c) {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(c))
            } else if !c.isWhitespace {
                current.append(c)
            }
            
            i = expr.index(after: i)
        }
        
        if !current.isEmpty {
            tokens.append(current)
        }
        
        // Need at least one value
        guard !tokens.isEmpty else { return nil }
        
        // Parse first value
        guard var result = parseValue(tokens[0]) else { return nil }
        
        // Process operator-value pairs
        var idx = 1
        while idx + 1 < tokens.count {
            let op = tokens[idx]
            guard let operand = parseValue(tokens[idx + 1]) else { return nil }
            
            switch op {
            case "+": result = result &+ operand
            case "-": result = result &- operand
            case "*": result = result &* operand
            case "/": result = operand == 0 ? 0 : result / operand
            case "%": result = operand == 0 ? 0 : result % operand
            case "&": result = result & operand
            case "|": result = result | operand
            case "^": result = result ^ operand
            case "<<": result = result << operand
            case ">>": result = result >> operand
            default: return nil
            }
            
            idx += 2
        }
        
        return result
    }
    
    private func parseValue(_ str: String) -> UInt64? {
        let cleaned = str.lowercased().trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return nil }
        
        if cleaned.hasPrefix("0x") {
            return UInt64(cleaned.dropFirst(2), radix: 16)
        } else if cleaned.hasPrefix("0b") {
            return UInt64(cleaned.dropFirst(2), radix: 2)
        } else if cleaned.hasPrefix("0o") {
            return UInt64(cleaned.dropFirst(2), radix: 8)
        } else {
            return UInt64(cleaned, radix: ctx.base.radix)
        }
    }
}

// MARK: - Display Area
struct DisplayArea: View {
    @Bindable var ctx: CalculatorContext
    @Binding var inputText: String
    var inputFocused: FocusState<Bool>.Binding
    
    var body: some View {
        VStack(spacing: 8) {
            // Base selector - subtle, top-right aligned
            HStack {
                // Close button
                Button(action: {
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
                
                // Pending operation indicator
                if ctx.hasPendingOp {
                    HStack(spacing: 4) {
                        Text(String(ctx.model.storedValue, radix: ctx.base.radix, uppercase: true))
                            .font(.system(size: 11, design: .monospaced))
                        Text(ctx.pendingOpSymbol)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                }
                
                Spacer()
                
                Picker("", selection: $ctx.base) {
                    ForEach(Base.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .padding(.horizontal)
            
            // Main input field
            HStack(alignment: .top, spacing: 8) {
                Text(ctx.base.prefix)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .padding(.top, 8)
                
                TextEditor(text: $inputText)
                    .focused(inputFocused)
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 40, maxHeight: 120)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            
            // Signed/Unsigned + Bit width - subtle controls
            HStack {
                // Memory indicator
                if ctx.hasMemory {
                    Label("M", systemImage: "memorychip")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                Picker("", selection: $ctx.signMode) {
                    ForEach(SignMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .scaleEffect(0.85)
                
                Picker("", selection: $ctx.bitWidth) {
                    ForEach(BitWidth.allCases) { Text("\($0.rawValue)").tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .scaleEffect(0.85)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Conversions Panel
struct ConversionsPanel: View {
    @Bindable var ctx: CalculatorContext
    
    var body: some View {
        VStack(spacing: 6) {
            ConversionRow(base: .hex, ctx: ctx)
            ConversionRow(base: .dec, ctx: ctx)
            ConversionRow(base: .oct, ctx: ctx)
            ConversionRow(base: .bin, ctx: ctx)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

struct ConversionRow: View {
    let base: Base
    @Bindable var ctx: CalculatorContext
    @State private var copied = false
    @State private var hovered = false
    
    var isActive: Bool { ctx.base == base }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Label
            Text(base.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(colorFor(base))
                .frame(width: 28, alignment: .leading)
                .padding(.top, 2)
            
            // Value - wraps naturally
            Text(formattedValue)
                .font(.system(size: 13, weight: isActive ? .medium : .regular, design: .monospaced))
                .foregroundStyle(isActive ? .primary : .secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Signed interpretation for decimal
            if base == .dec && ctx.signMode == .signed {
                let signed = ctx.model.signedValue
                if signed < 0 {
                    Text("(\(signed))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }
            
            // Copy button - appears on hover
            Button(action: copy) {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(copied ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovered || copied ? 1 : 0)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(6)
        .onHover { hovered = $0 }
    }
    
    var formattedValue: String {
        ctx.formattedGrouped(base: base)
    }
    
    func colorFor(_ base: Base) -> Color {
        switch base {
        case .hex: .orange
        case .dec: .blue
        case .oct: .green
        case .bin: .purple
        }
    }
    
    func copy() {
        ctx.copyToClipboard(base: base)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }
}

// MARK: - Controls Area
struct ControlsArea: View {
    @Bindable var ctx: CalculatorContext
    @Binding var inputText: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Quick actions row
            HStack(spacing: 8) {
                QuickAction("Clear", icon: "xmark.circle") {
                    ctx.clearAll()
                    inputText = ""
                }
                QuickAction("NOT", icon: "exclamationmark.triangle") {
                    ctx.bitwiseNot()
                    inputText = ctx.formatted(base: ctx.base)
                }
                QuickAction("±", icon: "plus.forwardslash.minus") {
                    ctx.toggleSign()
                    inputText = ctx.formatted(base: ctx.base)
                }
                
                Spacer()
                
                // Memory buttons
                HStack(spacing: 4) {
                    MemButton("MC", active: ctx.hasMemory) { ctx.mc() }
                    MemButton("MR", active: ctx.hasMemory) {
                        ctx.mr()
                        inputText = ctx.formatted(base: ctx.base)
                    }
                    MemButton("M+", active: ctx.hasMemory) { ctx.mPlus() }
                    MemButton("MS", active: false) { ctx.ms() }
                }
            }
            .padding(.horizontal)
            
            // Arithmetic operations
            HStack(spacing: 6) {
                ArithmeticButton("+") { ctx.operation(.add); inputText = "" }
                ArithmeticButton("−") { ctx.operation(.subtract); inputText = "" }
                ArithmeticButton("×") { ctx.operation(.multiply); inputText = "" }
                ArithmeticButton("÷") { ctx.operation(.divide); inputText = "" }
                ArithmeticButton("%") { ctx.operation(.mod); inputText = "" }
                
                Button("=") {
                    ctx.equals()
                    inputText = ctx.formatted(base: ctx.base)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal)
            
            // Bitwise operations
            HStack(spacing: 6) {
                BitwiseButton("AND") { ctx.operation(.and); inputText = "" }
                BitwiseButton("OR") { ctx.operation(.or); inputText = "" }
                BitwiseButton("XOR") { ctx.operation(.xor); inputText = "" }
                BitwiseButton("<<") { ctx.operation(.shiftLeft); inputText = "" }
                BitwiseButton(">>") { ctx.operation(.shiftRight); inputText = "" }
            }
            .padding(.horizontal)
            
            // Footer
            VStack(spacing: 4) {
                Text("Type directly • Use 0x 0b 0o prefixes")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
                HStack(spacing: 4) {
                    Link("Made by Kush S.", destination: URL(string: "https://skushagra.com")!)
                        .font(.system(size: 10))
                        .underline()
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .padding(.top, 10)
    }
}

struct QuickAction: View {
    let label: String
    let icon: String
    let action: () -> Void
    
    init(_ label: String, icon: String, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct MemButton: View {
    let label: String
    let active: Bool
    let action: () -> Void
    
    init(_ label: String, active: Bool, action: @escaping () -> Void) {
        self.label = label
        self.active = active
        self.action = action
    }
    
    var body: some View {
        Button(label, action: action)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(active ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.1))
            .foregroundStyle(active ? .orange : .secondary)
            .cornerRadius(4)
    }
}

struct ArithmeticButton: View {
    let label: String
    let action: () -> Void
    
    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }
    
    var body: some View {
        Button(label, action: action)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.12))
            .foregroundStyle(.blue)
            .cornerRadius(5)
    }
}

struct BitwiseButton: View {
    let label: String
    let action: () -> Void
    
    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }
    
    var body: some View {
        Button(label, action: action)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.purple.opacity(0.12))
            .foregroundStyle(.purple)
            .cornerRadius(5)
    }
}

// MARK: - Context Extension
extension CalculatorContext {
    var pendingOpSymbol: String {
        guard let op = model.pendingOperation else { return "" }
        switch op {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        case .mod: return "%"
        case .and: return "AND"
        case .or: return "OR"
        case .xor: return "XOR"
        case .nand: return "NAND"
        case .nor: return "NOR"
        case .xnor: return "XNOR"
        case .shiftLeft: return "<<"
        case .shiftRight: return ">>"
        case .rotateLeft: return "ROL"
        case .rotateRight: return "ROR"
        }
    }
}
