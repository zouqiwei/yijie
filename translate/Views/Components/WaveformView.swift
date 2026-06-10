//
//  WaveformView.swift
//  translate
//

import SwiftUI

/// 实时音量波形动画组件
struct WaveformView: View {
    var audioLevel: Float
    var isRecording: Bool
    var theme: AppTheme = .classic

    private let barCount = 30
    @State private var heights: [CGFloat] = Array(repeating: 3, count: 30)

    private var gradient: LinearGradient {
        LinearGradient(
            colors: theme.colors,
            startPoint: .bottom,
            endPoint: .top
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(gradient)
                    .frame(width: 3, height: heights[i])
            }
        }
        .frame(height: 60)
        .onChange(of: audioLevel) { _, level in
            animateBars(level: level)
        }
        .onChange(of: isRecording) { _, recording in
            if !recording {
                withAnimation(.easeOut(duration: 0.5)) {
                    heights = Array(repeating: 3, count: barCount)
                }
            }
        }
    }

    private func animateBars(level: Float) {
        withAnimation(.easeInOut(duration: 0.08)) {
            heights = (0..<barCount).map { i in
                // 中间高，两侧矮，制造中心对称效果
                let mirror = min(i, barCount - 1 - i)
                let centerFactor = 1.0 - CGFloat(mirror) / CGFloat(barCount / 2) * 0.35
                let noise = CGFloat.random(in: 0.4...1.0)
                let h = CGFloat(level) * 56 * centerFactor * noise
                return max(3, h)
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.07, green: 0.07, blue: 0.15)
        WaveformView(audioLevel: 0.6, isRecording: true)
    }
}
