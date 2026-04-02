import SwiftUI

struct AssigneeAvatar: View {
    let type: String?
    let name: String
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(type == "agent" ? Color.purple.opacity(0.2) : Color.gray.opacity(0.2))
                .frame(width: size, height: size)

            if type == "agent" {
                Image(systemName: "cpu")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.purple)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
