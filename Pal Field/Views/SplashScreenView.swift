//
//  SplashScreenView.swift
//  Pal Field
//
//  Created by Claude on 2/2/26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var showDot = false
    @State private var showArc1 = false
    @State private var showArc2 = false
    @State private var showArc3 = false
    @State private var showSmile = false
    @State private var showText = false
    @Binding var isFinished: Bool

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Logo - WiFi-like signal with animations
                ZStack {
                    // Arc 3 (outermost/top)
                    SignalArc(startAngle: -145, endAngle: -35, lineWidth: 14)
                        .stroke(brandGreen, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .offset(y: -60)
                        .opacity(showArc3 ? 1 : 0)
                        .scaleEffect(showArc3 ? 1 : 0.8)

                    // Arc 2 (middle)
                    SignalArc(startAngle: -145, endAngle: -35, lineWidth: 14)
                        .stroke(brandGreen, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .frame(width: 110, height: 110)
                        .offset(y: -35)
                        .opacity(showArc2 ? 1 : 0)
                        .scaleEffect(showArc2 ? 1 : 0.8)

                    // Arc 1 (innermost, above dot)
                    SignalArc(startAngle: -145, endAngle: -35, lineWidth: 12)
                        .stroke(brandGreen, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .offset(y: -10)
                        .opacity(showArc1 ? 1 : 0)
                        .scaleEffect(showArc1 ? 1 : 0.8)

                    // Center dot
                    Ellipse()
                        .fill(brandGreen)
                        .frame(width: 24, height: 30)
                        .offset(y: 25)
                        .opacity(showDot ? 1 : 0)
                        .scaleEffect(showDot ? 1 : 0)

                    // Bottom smile arc
                    SignalArc(startAngle: 35, endAngle: 145, lineWidth: 12)
                        .stroke(brandGreen, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .offset(y: 60)
                        .opacity(showSmile ? 1 : 0)
                        .scaleEffect(showSmile ? 1 : 0.8)
                }
                .frame(height: 220)

                // Company name
                VStack(spacing: 8) {
                    Text("PAL LOW VOLTAGE LLC")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(brandGreen)
                        .tracking(1)

                    Text("QUALITY RELIABLE EFFICIENT")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(brandGreen)
                        .tracking(2)
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 20)
            }
        }
        .onAppear {
            animateSequence()
        }
    }

    private func animateSequence() {
        // Dot appears first
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showDot = true
        }

        // Arc 1 (closest to dot)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showArc1 = true
            }
        }

        // Arc 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showArc2 = true
            }
        }

        // Arc 3 (outermost)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showArc3 = true
            }
        }

        // Smile arc
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showSmile = true
            }
        }

        // Text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                showText = true
            }
        }

        // Finish and transition to app
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isFinished = true
            }
        }
    }
}

// Custom arc shape for the signal waves
struct SignalArc: Shape {
    var startAngle: Double
    var endAngle: Double
    var lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )

        return path
    }
}

#Preview {
    SplashScreenView(isFinished: .constant(false))
}
