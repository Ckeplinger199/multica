import SwiftUI

struct PriorityIcon: View {
    let priority: IssuePriority
    var size: CGFloat = 14

    var body: some View {
        Group {
            switch priority {
            case .urgent:
                Image(systemName: "exclamationmark.3")
                    .foregroundStyle(.red)
            case .high:
                Image(systemName: "exclamationmark.2")
                    .foregroundStyle(.orange)
            case .medium:
                Image(systemName: "exclamationmark")
                    .foregroundStyle(.yellow)
            case .low:
                Image(systemName: "arrow.down")
                    .foregroundStyle(.blue)
            case .none:
                Image(systemName: "minus")
                    .foregroundStyle(.gray)
            }
        }
        .font(.system(size: size, weight: .medium))
    }
}
