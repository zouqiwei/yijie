//
//  TranslationResultCard.swift
//  translate
//

import SwiftUI
import AVFoundation

/// 翻译结果展示卡片，含复制和朗读功能
struct TranslationResultCard: View {
    let text: String
    let language: LanguageOption
    var speechRate: Float = 0.48 // 默认语速
    var theme: AppTheme = .classic
    
    var isFavorite: Bool = false
    var onToggleFavorite: (() -> Void)? = nil

    @State private var isCopied = false
    @State private var isSpeaking = false
    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── 标题行 ──
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(language.flag)
                        .font(.title3)
                    Text(language.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                HStack(spacing: 16) {
                    // 朗读按钮
                    Button(action: toggleSpeech) {
                        Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(
                                isSpeaking
                                ? theme.colors[0]
                                : Color.white.opacity(0.55)
                            )
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)

                    // 收藏按钮
                    if let onToggleFavorite = onToggleFavorite {
                        Button(action: onToggleFavorite) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(
                                    isFavorite
                                    ? .yellow
                                    : Color.white.opacity(0.55)
                                )
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                    }

                    // 复制按钮
                    Button(action: copy) {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(
                                isCopied
                                ? theme.colors[0]
                                : Color.white.opacity(0.55)
                            )
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)

                    // 分享按钮
                    ShareLink(item: text) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── 结果文本 ──
            Text(text)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    theme.colors[0].opacity(0.55),
                                    theme.colors[1].opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Actions

    private func copy() {
        UIPasteboard.general.string = text
        withAnimation(.spring(duration: 0.3)) { isCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { isCopied = false }
        }
    }

    private func toggleSpeech() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.speechLocaleIdentifier)
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        isSpeaking = true
        synthesizer.speak(utterance)

        // 粗略估计朗读完成时间后重置状态
        let estimatedDuration = max(2.0, Double(text.count) * 0.18)
        Task {
            try? await Task.sleep(for: .seconds(estimatedDuration))
            isSpeaking = false
        }
    }
}
