import SwiftUI

/// SwiftUI's semantic fonts render smaller on macOS than on iOS
/// (`.body` is 17pt iOS / 13pt macOS, `.caption` 12pt / 11pt, etc.).
/// In a narrow news-reader window the macOS defaults feel cramped,
/// so these variants map to iOS-matched sizes on macOS while
/// preserving the native Dynamic Type behavior on iOS.
extension Font {
    static var jtfBody: Font {
        #if os(macOS)
        .system(size: 16)
        #else
        .body
        #endif
    }

    static var jtfCallout: Font {
        #if os(macOS)
        .system(size: 15)
        #else
        .callout
        #endif
    }

    static var jtfSubheadline: Font {
        #if os(macOS)
        .system(size: 14)
        #else
        .subheadline
        #endif
    }

    static var jtfCaption: Font {
        #if os(macOS)
        .system(size: 12)
        #else
        .caption
        #endif
    }

    static var jtfCaption2: Font {
        #if os(macOS)
        .system(size: 11)
        #else
        .caption2
        #endif
    }

    static var jtfHeadline: Font {
        #if os(macOS)
        .system(size: 16, weight: .semibold)
        #else
        .headline
        #endif
    }

    static var jtfTitle: Font {
        #if os(macOS)
        .system(size: 22, weight: .semibold)
        #else
        .title
        #endif
    }
}
