//
//  VoiceInputView.swift
//  translate
//

import SwiftUI
import Speech

/// 语音录入模式：麦克风 + 波形动画 + 实时文字
struct VoiceInputView: View {
    @Bindable var speechVM: SpeechViewModel
    let sourceLocale: String    // 源语言的 locale 标识符，如 "zh-CN"
    var theme: AppTheme = .classic
    var onTranslate: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.55

    private var themeStart: Color { theme.colors[0] }
    private var themeEnd:   Color { theme.colors[1] }
    private let recordStart = Color(red: 0.85, green: 0.25, blue: 0.35)
    private let recordEnd   = Color(red: 0.96, green: 0.38, blue: 0.38)

    var body: some View {
        VStack(spacing: 20) {
            // ── 显示区 ──
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                speechVM.isRecording
                                ? recordStart.opacity(0.5)
                                : Color.white.opacity(0.10),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(
                        color: speechVM.isRecording
                            ? recordStart.opacity(0.6)
                            : themeStart.opacity(0.5),
                        radius: speechVM.isRecording ? 16 : 10,
                        x: 0, y: 5
                    )
                    .animation(.easeInOut(duration: 0.3), value: speechVM.isRecording)

                Group {
                    if speechVM.isRecording {
                        // 录音中：波形 + 提示
                        VStack(spacing: 12) {
                            WaveformView(audioLevel: speechVM.audioLevel,
                                         isRecording: speechVM.isRecording,
                                         theme: theme)
                                .padding(.horizontal, 20)

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(recordStart)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(pulseScale)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                               value: pulseScale)

                                Text("正在聆听…")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }

                    } else if !speechVM.recognizedText.isEmpty {
                        // 显示识别结果
                        ScrollView {
                            Text(speechVM.recognizedText)
                                .font(.body)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .frame(maxHeight: 130)

                    } else {
                        // 空状态提示
                        VStack(spacing: 10) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    LinearGradient(colors: [themeStart.opacity(0.6), themeEnd.opacity(0.6)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            Text("点击麦克风开始录音")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.38))
                        }
                    }
                }
                .frame(minHeight: 130)
                .padding(16)
            }

            // ── 错误提示 ──
            if let err = speechVM.errorMessage {
                errorBanner(err)
            }

            // ── 按钮行 ──
            HStack(spacing: 24) {
                // 清空按钮
                if !speechVM.recognizedText.isEmpty && !speechVM.isRecording {
                    circleIconButton(icon: "trash", color: .white.opacity(0.55)) {
                        speechVM.clear()
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // 麦克风 / 停止按钮
                Button(action: toggleRecording) {
                    ZStack {
                        if speechVM.isRecording {
                            // 脉冲环
                            ForEach([0, 1], id: \.self) { idx in
                                Circle()
                                    .fill(recordStart.opacity(idx == 0 ? 0.25 : 0.12))
                                    .frame(width: CGFloat(72 + idx * 24),
                                           height: CGFloat(72 + idx * 24))
                                    .scaleEffect(pulseScale + CGFloat(idx) * 0.12)
                                    .opacity(pulseOpacity)
                            }
                        }

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: speechVM.isRecording
                                        ? [recordStart, recordEnd]
                                        : [themeStart, themeEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                            .shadow(color: speechVM.isRecording
                                    ? recordStart.opacity(0.5)
                                    : themeStart.opacity(0.45),
                                    radius: 16, x: 0, y: 8)

                        Image(systemName: speechVM.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .onChange(of: speechVM.isRecording) { _, recording in
                    if recording {
                        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                            pulseScale = 1.25
                            pulseOpacity = 0.0
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) {
                            pulseScale = 1.0
                            pulseOpacity = 0.55
                        }
                    }
                }

                // 翻译快捷按钮
                if !speechVM.recognizedText.isEmpty && !speechVM.isRecording {
                    circleIconButton(
                        icon: "arrow.triangle.2.circlepath",
                        gradient: [themeStart, themeEnd]
                    ) {
                        onTranslate()
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: speechVM.recognizedText.isEmpty)
            .animation(.spring(duration: 0.3), value: speechVM.isRecording)

            // 未授权提示
            if speechVM.speechAuthStatus == .denied || speechVM.speechAuthStatus == .restricted {
                Text("请前往「设置 › 隐私 › 语音识别」授权本 App")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Helpers

    private func toggleRecording() {
        if speechVM.isRecording {
            speechVM.stopRecording()
        } else {
            Task {
                await speechVM.startRecording(localeIdentifier: sourceLocale)
            }
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(msg)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Button { speechVM.errorMessage = nil } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.4))
                    .font(.caption)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        )
    }

    private func circleIconButton(icon: String,
                                  color: Color = .white,
                                  gradient: [Color]? = nil,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        gradient != nil
                        ? AnyShapeStyle(LinearGradient(colors: gradient!, startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
