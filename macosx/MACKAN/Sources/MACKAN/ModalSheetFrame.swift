import SwiftUI

import MACKANKit

enum MackanModalSheetFrameStyle {
    case compact
    case standard
    case wide
}

extension View {
    func mackanModalSheetFrame(_ style: MackanModalSheetFrameStyle) -> some View {
        switch style {
        case .compact:
            frame(
                minWidth: CGFloat(ModalSheetLayoutPolicy.compactMinimumWidth),
                idealWidth: CGFloat(ModalSheetLayoutPolicy.compactIdealWidth),
                maxWidth: .infinity,
                minHeight: CGFloat(ModalSheetLayoutPolicy.compactMinimumHeight),
                idealHeight: CGFloat(ModalSheetLayoutPolicy.compactIdealHeight),
                maxHeight: .infinity)
        case .standard:
            frame(
                minWidth: CGFloat(ModalSheetLayoutPolicy.standardMinimumWidth),
                idealWidth: CGFloat(ModalSheetLayoutPolicy.standardIdealWidth),
                maxWidth: CGFloat(ModalSheetLayoutPolicy.standardMaximumWidth),
                minHeight: CGFloat(ModalSheetLayoutPolicy.standardMinimumHeight),
                idealHeight: CGFloat(ModalSheetLayoutPolicy.standardIdealHeight),
                maxHeight: CGFloat(ModalSheetLayoutPolicy.standardMaximumHeight))
        case .wide:
            frame(
                minWidth: CGFloat(ModalSheetLayoutPolicy.wideMinimumWidth),
                idealWidth: CGFloat(ModalSheetLayoutPolicy.wideIdealWidth),
                maxWidth: CGFloat(ModalSheetLayoutPolicy.wideMaximumWidth),
                minHeight: CGFloat(ModalSheetLayoutPolicy.standardMinimumHeight),
                idealHeight: CGFloat(ModalSheetLayoutPolicy.standardIdealHeight),
                maxHeight: CGFloat(ModalSheetLayoutPolicy.standardMaximumHeight))
        }
    }
}
