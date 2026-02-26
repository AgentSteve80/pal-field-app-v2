//
//  DesignSystem.swift
//  PreWire Pro - Technical Blueprint Design System
//
//  A professional, industrial design system inspired by blueprints and technical drawings
//

import SwiftUI

// MARK: - Color Palette

extension Color {
    // Primary Blueprint Industrial Palette
    static let blueprintBlue = Color(red: 0.05, green: 0.28, blue: 0.63)      // #0D47A1
    static let constructionOrange = Color(red: 1.0, green: 0.42, blue: 0.21)  // #FF6B35
    static let steelGray = Color(red: 0.22, green: 0.28, blue: 0.31)          // #37474F
    static let gridGray = Color(red: 0.69, green: 0.74, blue: 0.77)           // #B0BEC5
    static let paperWhite = Color(red: 0.96, green: 0.97, blue: 0.98)         // #F5F7FA
    static let successGreen = Color(red: 0.0, green: 0.78, blue: 0.33)        // #00C853
    static let warningAmber = Color(red: 1.0, green: 0.75, blue: 0.0)         // #FFC000

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography System

extension Font {
    // Technical typography with emphasis on data and numbers
    static let technicalTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let technicalHeadline = Font.system(size: 20, weight: .semibold, design: .default)
    static let technicalBody = Font.system(size: 16, weight: .regular, design: .default)
    static let technicalCaption = Font.system(size: 12, weight: .medium, design: .default).uppercaseSmallCaps()
    static let technicalMono = Font.system(size: 16, weight: .medium, design: .monospaced)
    static let technicalMonoLarge = Font.system(size: 24, weight: .semibold, design: .monospaced)
}

// MARK: - Blueprint Grid Background

struct BlueprintGridBackground: View {
    let spacing: CGFloat = 20
    let lineWidth: CGFloat = 0.5

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Vertical lines
                let verticalLines = Int(geometry.size.width / spacing)
                for i in 0...verticalLines {
                    let x = CGFloat(i) * spacing
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }

                // Horizontal lines
                let horizontalLines = Int(geometry.size.height / spacing)
                for i in 0...horizontalLines {
                    let y = CGFloat(i) * spacing
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.gridGray.opacity(0.3), lineWidth: lineWidth)
        }
    }
}

// MARK: - Technical Corner Brackets

struct TechnicalCorners: View {
    let size: CGFloat = 12
    let lineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height

                // Top-left
                path.move(to: CGPoint(x: 0, y: size))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))

                // Top-right
                path.move(to: CGPoint(x: width - size, y: 0))
                path.addLine(to: CGPoint(x: width, y: 0))
                path.addLine(to: CGPoint(x: width, y: size))

                // Bottom-left
                path.move(to: CGPoint(x: 0, y: height - size))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: size, y: height))

                // Bottom-right
                path.move(to: CGPoint(x: width - size, y: height))
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: width, y: height - size))
            }
            .stroke(Color.blueprintBlue.opacity(0.4), lineWidth: lineWidth)
        }
    }
}

// MARK: - Technical Stat Card

struct TechnicalStatCard: View {
    let title: String
    let value: String
    let unit: String
    let subtitle: String?
    let accentColor: Color
    let icon: String?

    init(title: String, value: String, unit: String, subtitle: String? = nil, accentColor: Color = .blueprintBlue, icon: String? = nil) {
        self.title = title
        self.value = value
        self.unit = unit
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.icon = icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accentColor)
                }
                Text(title)
                    .font(.technicalCaption)
                    .foregroundStyle(Color.steelGray)
                    .tracking(1)
            }

            Spacer()

            // Value in monospace
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.technicalMonoLarge)
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.technicalCaption)
                    .foregroundStyle(.secondary)
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            ZStack {
                Color(.secondarySystemBackground)
                TechnicalCorners()
                    .padding(4)
            }
        )
        .overlay(
            Rectangle()
                .fill(accentColor)
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Technical Navigation Card

struct TechnicalNavCard: View {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 16) {
            // Icon with technical frame
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 50, height: 50)

                RoundedRectangle(cornerRadius: 2)
                    .stroke(accentColor, lineWidth: 2)
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.technicalHeadline)
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.gridGray)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .overlay(
            TechnicalCorners()
                .padding(6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Section Header with Measurement Line

struct TechnicalSectionHeader: View {
    let title: String
    let count: Int?

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.technicalHeadline)
                .foregroundStyle(.primary)

            if let count = count {
                Text("[\(count)]")
                    .font(.technicalMono)
                    .foregroundStyle(Color.blueprintBlue)
            }

            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
        }
        .padding(.horizontal)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}
