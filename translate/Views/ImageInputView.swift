//
//  ImageInputView.swift
//  translate
//

import SwiftUI
import PhotosUI

/// 图片 OCR 模式：相册选取 / 拍照 → Vision 识别文字
struct ImageInputView: View {
    @Bindable var ocrVM: ImageOCRViewModel
    var theme: AppTheme = .classic
    var onTranslate: () -> Void

    @State private var showCamera = false

    private var themeStart: Color { theme.colors[0] }
    private var themeEnd: Color { theme.colors[1] }

    var body: some View {
        VStack(spacing: 16) {
            // ── 操作按钮行 ──
            HStack(spacing: 12) {
                // 相册
                PhotosPicker(selection: $ocrVM.photoItem, matching: .images, photoLibrary: .shared()) {
                    actionLabel(icon: "photo.on.rectangle", title: "选择图片")
                }
                .buttonStyle(.plain)
                .onChange(of: ocrVM.photoItem) { _, _ in
                    Task { await ocrVM.loadPhotoItem() }
                }

                // 相机（模拟器无相机时隐藏）
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        actionLabel(icon: "camera.fill", title: "拍摄照片")
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            // ── 图片预览 ──
            if let img = ocrVM.selectedImage {
                ZStack(alignment: .center) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(maxHeight: 220)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    if ocrVM.isProcessing {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.black.opacity(0.55))
                        VStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.3)
                            Text("正在识别文字…")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(maxHeight: 220)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // ── OCR 识别结果 ──
            if !ocrVM.recognizedTexts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "text.viewfinder")
                            .foregroundStyle(themeStart)
                            .font(.system(size: 14, weight: .semibold))
                        Text("识别到的文字")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Button {
                            withAnimation { ocrVM.clear() }
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.white.opacity(0.38))
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView {
                        Text(ocrVM.combinedText)
                            .font(.body)
                            .foregroundStyle(.white)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .frame(maxHeight: 130)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )

                    // 翻译按钮
                    Button(action: onTranslate) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .semibold))
                            Text("翻译识别文字")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(colors: [themeStart, themeEnd],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── 空状态占位 ──
            if ocrVM.selectedImage == nil {
                emptyPlaceholder
            }

            // ── 错误提示 ──
            if let err = ocrVM.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Button { ocrVM.errorMessage = nil } label: {
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
        }
        .animation(.spring(duration: 0.35), value: ocrVM.recognizedTexts.isEmpty)
        .animation(.spring(duration: 0.35), value: ocrVM.selectedImage == nil)
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                showCamera = false
                if let img = image {
                    Task { await ocrVM.processImage(img) }
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Sub-views

    private var emptyPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.magnifyingglass")
                .font(.system(size: 46))
                .foregroundStyle(.white.opacity(0.22))
            Text("选择图片或拍照\n自动识别图中文字")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.28))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(Color.white.opacity(0.12))
                )
        )
    }

    private func actionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.14), lineWidth: 1))
        )
    }
}
