public enum OperationPresentationSheet: Equatable, Sendable {
    case none
    case changePreview
    case operationResult
}

public struct OperationPresentationState: Equatable, Sendable {
    public private(set) var presentedSheet: OperationPresentationSheet

    public init(presentedSheet: OperationPresentationSheet = .none) {
        self.presentedSheet = presentedSheet
    }

    public func isPresenting(_ sheet: OperationPresentationSheet) -> Bool {
        sheet != .none && presentedSheet == sheet
    }

    public mutating func present(_ sheet: OperationPresentationSheet) {
        presentedSheet = sheet
    }

    public mutating func dismiss(_ sheet: OperationPresentationSheet) {
        if presentedSheet == sheet {
            presentedSheet = .none
        }
    }

    public mutating func clear() {
        presentedSheet = .none
    }
}
