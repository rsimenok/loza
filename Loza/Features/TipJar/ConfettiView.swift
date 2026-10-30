//
//  ConfettiView.swift
//  Loza
//
//  Created by Roman Simenok on 30.10.2026.
//

import SwiftUI

/// Animated confetti particle effect celebrating successful purchases.
struct ConfettiView: View {
    @State private var animate = false

    private let colors: [Color] = [.pink, .purple, .blue, .green, .yellow, .orange, .red]
    private let particleCount = 36

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<particleCount, id: \.self) { index in
                    let color = colors[index % colors.count]
                    let randomAngle = Double.random(in: 0...(2 * .pi))
                    let randomDistance = CGFloat.random(in: 60...max(proxy.size.width, proxy.size.height) * 0.7)
                    let randomSize = CGFloat.random(in: 6...12)
                    let randomRotation = Double.random(in: 180...720)

                    Circle()
                        .fill(color)
                        .frame(width: randomSize, height: randomSize)
                        .scaleEffect(animate ? CGFloat.random(in: 0.5...1.2) : 0.1)
                        .offset(
                            x: animate ? cos(randomAngle) * randomDistance : 0,
                            y: animate ? sin(randomAngle) * randomDistance : 0
                        )
                        .rotationEffect(.degrees(animate ? randomRotation : 0))
                        .opacity(animate ? 0 : 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.2)) {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.black
        ConfettiView()
    }
}
