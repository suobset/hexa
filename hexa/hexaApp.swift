//
//  hexaApp.swift
//  hexa
//
//  Created by Kushagra Srivastava on 1/28/26.
//

import SwiftUI

@main
struct hexaApp: App {
    var body: some Scene {
        MenuBarExtra("hexa", systemImage: "number.square") {
            CalculatorView()
        }
        .menuBarExtraStyle(.window)
    }
}
