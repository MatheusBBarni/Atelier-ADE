import AppKit
import NativeMacADECore
import SwiftUI

private enum AgentProfileBrand {
    case codex
    case claude
    case opencode
    case generic

    var fallbackSystemImage: String {
        switch self {
        case .codex:
            return "sparkles"
        case .claude:
            return "sun.max.fill"
        case .opencode:
            return "chevron.left.slash.chevron.right"
        case .generic:
            return "terminal"
        }
    }

    func assetName() -> String? {
        switch self {
        case .codex:
            return "codex"
        case .claude:
            return "claude"
        case .opencode:
            return "opencode"
        case .generic:
            return nil
        }
    }
}

extension SessionShortcut {
    fileprivate var agentProfileBrand: AgentProfileBrand {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCommand = launchCommand.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedLabel == "codex" || normalizedCommand == "codex" {
            return .codex
        }

        if normalizedLabel == "claude" || normalizedCommand == "claude" {
            return .claude
        }

        if normalizedLabel == "opencode" || normalizedCommand == "opencode" {
            return .opencode
        }

        return .generic
    }
}

struct AgentProfileIconView: View {
    let shortcut: SessionShortcut?
    var fallbackSystemImage: String?
    var size: CGFloat = 18

    @Environment(\.shellThemePalette) private var theme

    var body: some View {
        if let brandImage {
            Image(nsImage: brandImage)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .foregroundStyle(shortcut?.isBuiltIn == true ? theme.primaryText.color : theme.secondaryAccent.color)
        } else {
            Image(systemName: resolvedFallbackSystemImage)
                .font(.system(size: max(size - 2, 11), weight: .semibold))
                .foregroundStyle(shortcut?.isBuiltIn == true ? theme.accent.color : theme.secondaryAccent.color)
                .frame(width: size, height: size)
        }
    }

    private var resolvedFallbackSystemImage: String {
        if let fallbackSystemImage {
            return fallbackSystemImage
        }

        if let shortcut {
            return shortcut.agentProfileBrand.fallbackSystemImage
        }

        return shortcut?.isBuiltIn == true ? "terminal.fill" : "terminal"
    }

    private var brandImage: NSImage? {
        guard let shortcut,
              let assetName = shortcut.agentProfileBrand.assetName(),
              let assetURL = brandAssetURL(named: assetName),
              let image = NSImage(contentsOf: assetURL)
        else {
            return nil
        }

        image.isTemplate = true
        return image
    }

    private func brandAssetURL(named assetName: String) -> URL? {
        if let svgURL = Bundle.module.url(forResource: assetName, withExtension: "svg", subdirectory: "BrandIcons") {
            return svgURL
        }

        if let pngURL = Bundle.module.url(forResource: assetName, withExtension: "png", subdirectory: "BrandIcons") {
            return pngURL
        }

        return nil
    }
}
