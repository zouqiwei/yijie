# Translation App Design

## Goal

Build the first usable version of an iOS translation app in the existing SwiftUI project. Users can type text manually, choose source and target languages, dictate speech into text, and extract text from photos or camera captures before translating it.

The first version prioritizes a complete app flow and clean replaceable architecture. Speech recognition and image OCR use real iOS system frameworks. Translation itself is represented by a mock service behind a protocol so a real online provider can be added later without reshaping the UI.

## Scope

Included in the first version:

- Single-screen SwiftUI translation workspace.
- Manual text input.
- Source and target language selection.
- One-tap language swap.
- Eight built-in languages: Chinese, English, Japanese, Korean, French, German, Spanish, and Russian.
- Speech-to-text input using iOS Speech and microphone capture.
- Image-to-text input from the photo library.
- Image-to-text input from the camera.
- OCR using Vision.
- Mock translation service with a replaceable service protocol.
- Clear loading, empty-input, permission, and failure states.

Not included in the first version:

- Real online translation API integration.
- Translation history.
- Favorites or saved phrases.
- Account system.
- Server-side API key proxy.
- Offline translation model management.

## User Experience

The app opens directly into a translation workspace rather than a landing page. The top area contains source and target language controls with a swap button between them. The main input area lets users type or review recognized text. A compact action row offers microphone, photo library, and camera input. A primary translate button runs translation, and the result appears below it.

Manual input flow:

1. User selects source and target languages.
2. User enters text.
3. User taps translate.
4. App shows translated result or a clear error message.

Speech input flow:

1. User taps the microphone action.
2. App requests speech and microphone permission if needed.
3. App records and transcribes speech.
4. Recognized text fills the input field.
5. User can edit the text before translating.

Image input flow:

1. User taps photo library or camera.
2. App obtains an image from the system picker or camera.
3. Vision OCR extracts text from the image.
4. Recognized text fills the input field.
5. User can edit the text before translating.

## Architecture

The app uses SwiftUI with a small set of focused types:

- `ContentView`: main screen layout and user interaction entry points.
- `TranslationViewModel`: observable state owner for selected languages, input text, result text, loading state, recognition state, image picker state, and errors.
- `TranslationLanguage`: supported language model with display names and framework language codes.
- `TranslationService`: protocol for translating text.
- `MockTranslationService`: first implementation that returns deterministic mock output.
- `SpeechRecognizer`: wrapper around Speech framework recording and transcription.
- `TextRecognizer`: wrapper around Vision text recognition for `UIImage` input.
- `ImagePicker`: UIKit bridge for camera/photo library where needed.

The UI talks to the view model. The view model coordinates services. Services do not own UI state. This keeps the first version simple while leaving room to replace `MockTranslationService` with a real network implementation later.

## Data Flow

State flows in one direction:

1. User action enters `ContentView`.
2. `ContentView` calls a method on `TranslationViewModel`.
3. `TranslationViewModel` validates input and starts the relevant service call.
4. Service returns recognized text, translated text, or an error.
5. `TranslationViewModel` updates published state.
6. SwiftUI refreshes the screen.

Language swap updates the selected source and target languages, and can also swap input/result text when a result is present.

## Permissions

The app needs user-facing permission descriptions for:

- Microphone access.
- Speech recognition.
- Camera access.
- Photo library access if required by the selected picker path.

Photo library selection should prefer system picker behavior that minimizes broad library permission requirements. Camera capture still requires camera permission.

## Error Handling

The first version handles:

- Empty input before translation.
- Speech recognition unavailable.
- Microphone or speech permission denied.
- Recording failure.
- Camera unavailable.
- Camera permission denied.
- Image picker cancellation.
- OCR returning no text.
- Translation service failure.

The UI should never remain stuck in a loading state after an error. Errors appear as concise alerts or inline status text depending on where they occur.

## Testing

Automated tests should focus on pure logic and view model behavior:

- Initial language defaults.
- Language swapping.
- Empty text validation.
- Mock translation result updates.
- OCR result insertion into input text.
- Error state updates.
- Loading state reset after success or failure.

System integrations such as live speech recognition, camera capture, and photo selection require manual simulator or device verification in the first version. The service wrappers should remain small so they can be protocol-backed and mocked more deeply later.

## Future Extension Points

Likely next steps after the first version:

- Replace `MockTranslationService` with a real API-backed implementation.
- Add copied result, share sheet, and result text-to-speech.
- Add translation history.
- Add automatic source language detection.
- Add search to the language picker if supported languages expand.
- Add a backend proxy for translation API keys.
