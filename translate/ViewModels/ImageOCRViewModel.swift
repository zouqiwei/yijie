//
//  ImageOCRViewModel.swift
//  translate
//

import SwiftUI
import Vision
import PhotosUI

/// 管理图片选取与 OCR 文字识别
@Observable
class ImageOCRViewModel {
    var selectedImage: UIImage?
    var recognizedTexts: [String] = []
    var combinedText: String = ""
    var isProcessing: Bool = false
    var errorMessage: String?

    /// 绑定 PhotosPicker 的选中项
    var photoItem: PhotosPickerItem?

    // MARK: - 图片来源

    /// 从相册加载选中的图片
    func loadPhotoItem() async {
        guard let item = photoItem else { return }
        isProcessing = true
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "图片加载失败"
                isProcessing = false
                return
            }
            selectedImage = image
            await recognizeText(in: image)
        } catch {
            errorMessage = "加载图片出错：\(error.localizedDescription)"
        }
        isProcessing = false
    }

    /// 处理从相机拍摄的图片
    func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        selectedImage = image
        await recognizeText(in: image)
        isProcessing = false
    }

    // MARK: - OCR

    private func recognizeText(in image: UIImage) async {
        guard let cgImage = image.cgImage else {
            errorMessage = "无效的图片格式"
            return
        }

        do {
            let texts = try await withCheckedThrowingContinuation {
                (cont: CheckedContinuation<[String], Error>) in

                let request = VNRecognizeTextRequest { req, err in
                    if let err {
                        cont.resume(throwing: err)
                        return
                    }
                    let observations = req.results as? [VNRecognizedTextObservation] ?? []
                    let strings = observations.compactMap {
                        $0.topCandidates(1).first?.string
                    }
                    cont.resume(returning: strings)
                }

                request.recognitionLevel = .accurate
                request.automaticallyDetectsLanguage = true
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(throwing: error)
                }
            }

            recognizedTexts = texts
            combinedText = texts.joined(separator: "\n")
        } catch {
            errorMessage = "文字识别失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 清空

    func clear() {
        selectedImage = nil
        recognizedTexts = []
        combinedText = ""
        errorMessage = nil
        photoItem = nil
    }
}
