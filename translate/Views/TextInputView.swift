//
//  TextInputView.swift
//  translate
//

import SwiftUI

/// 手动文本输入模式
struct TextInputView: View {
    @Bindable var vm: TranslationViewModel
    var theme: AppTheme = .classic

    @FocusState private var isFocused: Bool

    // 动态提取颜色
    private var themeStart: Color { theme.colors[0] }
    private var themeEnd: Color { theme.colors[1] }

    var body: some View {
        VStack(spacing: 0) {
            // ── 输入卡片 ──
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                            isFocused
                            ? themeStart.opacity(0.7)
                            : Color.white.opacity(0.1),
                                lineWidth: 1.2
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: isFocused)

                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        // 占位提示
                        if vm.inputText.isEmpty {
                            Text("输入需要翻译的文字…")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.28))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }

                        // 文本编辑器
                        TextEditor(text: $vm.inputText)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .foregroundStyle(.white)
                            .font(.body)
                            .frame(minHeight: 130, maxHeight: 220)
                            .focused($isFocused)
                    }

                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.top, 4)

                    // ── 底部工具栏 ──
                    HStack(spacing: 0) {
                        Text("\(vm.inputText.count) 字")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.32))

                        Spacer()

                        if !vm.inputText.isEmpty {
                            Button(action: clearText) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13))
                                    Text("清空")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white.opacity(0.38))
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                    .padding(.top, 8)
                    .animation(.spring(duration: 0.25), value: vm.inputText.isEmpty)
                }
                .padding(16)
            }
        }
    }

    private func clearText() {
        vm.inputText = ""
        vm.translatedText = ""
        vm.errorMessage = nil
    }
}
