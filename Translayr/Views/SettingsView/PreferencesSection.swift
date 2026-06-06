//
//  PreferencesSection.swift
//  Translayr
//

import SwiftUI

enum PreferencesSection: String, CaseIterable, Identifiable {
    case general = "General"
    case behavior = "Behavior"
    case backend = "Backend"
    case language = "Language"
    case models = "Ollama Models"
    case shortcuts = "Shortcuts"
    case skipApps = "Skip Apps"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .behavior: return "wand.and.stars"
        case .backend: return "server.rack"
        case .language: return "globe"
        case .models: return "cpu"
        case .shortcuts: return "keyboard"
        case .skipApps: return "eraser"
        case .about: return "info.circle"
        }
    }
}
