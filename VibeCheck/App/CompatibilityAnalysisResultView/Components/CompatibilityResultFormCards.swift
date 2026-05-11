import SwiftUI

struct CompatibilityResultSliderCard: View {
    let title: String
    @Binding var value: Double
    let minLabel: String
    let maxLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)

            Slider(value: $value, in: 1...10, step: 1)
                .tint(Color(crHex: 0x1D4ED8))

            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .resultGlassCard(cornerRadius: 21, shadowRadius: 11, shadowY: 5)
    }
}

struct CompatibilityResultBinaryChoiceCard: View {
    let title: String
    @Binding var value: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Button {
                    value = false
                } label: {
                    Text("Hayır")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(value ? Color(.secondarySystemBackground) : Color(crHex: 0xE9E7ED))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    value = true
                } label: {
                    Text("Evet")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(value ? Color(crHex: 0x2563EB) : Color(.secondarySystemBackground))
                        .foregroundStyle(value ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .resultGlassCard(cornerRadius: 21, shadowRadius: 11, shadowY: 5)
    }
}

struct CompatibilityResultReadonlySliderCard: View {
    let title: String
    let value: Int
    let minLabel: String
    let maxLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(value)/10")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(crHex: 0x4C4ACA))
            }

            ProgressView(value: Double(value), total: 10)
                .tint(Color(crHex: 0x4C4ACA))

            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .resultGlassCard(cornerRadius: 21, shadowRadius: 11, shadowY: 5)
    }
}

struct CompatibilityResultReadonlyBinaryCard: View {
    let title: String
    let value: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Text("Hayır")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(value ? Color(.secondarySystemBackground) : Color(crHex: 0xE9E7ED))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Evet")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(value ? Color(crHex: 0x4C4ACA) : Color(.secondarySystemBackground))
                    .foregroundStyle(value ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .resultGlassCard(cornerRadius: 21, shadowRadius: 11, shadowY: 5)
    }
}
