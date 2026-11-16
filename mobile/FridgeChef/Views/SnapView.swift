import SwiftUI
import PhotosUI

struct SnapView: View {
    @Environment(AppState.self) private var state
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Step 1 · Snap")
                    Text("“Nothing to eat”?\nLet’s see about that.")
                        .font(Theme.serif(32))
                        .foregroundStyle(Theme.ink)
                    Text("Photograph your fridge. We’ll find what’s in there and turn it into tonight’s menu.")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 8, matching: .images) {
                        Label("Choose photos", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: {
                            Label("Take photo", systemImage: "camera")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }

                if !state.photos.isEmpty { photoStrip }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb").foregroundStyle(Theme.accent)
                    Text("**Messy fridge?** Take one close-up per shelf — and one of the door. More photos, better guesses.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.soft)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 10) {
                    Button("Find my ingredients") { Task { await state.findIngredients() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(state.photos.isEmpty)
                        .opacity(state.photos.isEmpty ? 0.45 : 1)
                    Button("Type ingredients instead") { state.typeInstead() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(20)
        }
        .onChange(of: pickerItems) { _, items in
            Task { await load(items) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in state.photos.append(image) }
                .ignoresSafeArea()
        }
    }

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("\(state.photos.count) photo\(state.photos.count == 1 ? "" : "s")", color: Theme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(state.photos.enumerated()), id: \.offset) { index, img in
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 96, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    state.photos.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white, .black.opacity(0.55))
                                }
                                .padding(4)
                            }
                    }
                }
            }
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                images.append(img)
            }
        }
        state.photos.append(contentsOf: images)
        pickerItems = []
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
