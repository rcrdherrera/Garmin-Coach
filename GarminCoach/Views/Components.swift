import SwiftUI

// MARK: - MetricCard

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    var unit: String = ""
    var subtitle: String? = nil
    var color: Color = .brutalRed

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .tracking(1)
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            if let sub = subtitle {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalBorder, lineWidth: 1))
    }
}

// MARK: - SmallMetricCard

struct SmallMetricCard: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = .brutalRed

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalBorder, lineWidth: 1))
    }
}

// MARK: - ErrorCard

struct ErrorCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.brutalRed)
                .frame(width: 3)
            Text(message)
                .font(.callout)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalRed.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - LoadingCard

struct LoadingCard: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.brutalRed)
            Text(message.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .tracking(1.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(white: 0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brutalBorder, lineWidth: 1))
    }
}
