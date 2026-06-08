extension Array where Element == String {
    func uniquedCaseInsensitive() -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for value in self {
            let key = value.lowercased()
            if seen.insert(key).inserted {
                unique.append(value)
            }
        }
        return unique
    }
}
