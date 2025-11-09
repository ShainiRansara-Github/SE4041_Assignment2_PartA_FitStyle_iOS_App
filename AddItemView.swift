import SwiftUI
import PhotosUI

struct AddItemView: View {
    @EnvironmentObject var store: WardrobeStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showCamera: Bool = false
    @State private var category: Category = .top
    @State private var detectedColor: Color? = nil
    @State private var detectedColorName: String? = nil
    @State private var detectedTone: String? = nil
    @State private var showSaved: Bool = false
    @State private var showHUD: Bool = false
    @State private var imageVisible: Bool = false
    @State private var savePulse: Bool = false
    @State private var isAnalyzing: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                showCamera = true
                            } label: {
                                Text("Capture Photo")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(AccentButtonStyle())

                            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                                Text("Upload Photo")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(OutlineButtonStyle())
                        }

                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color(.systemGray5))
                                )
                            Group {
                                if let uiImage = selectedImage {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .opacity(imageVisible ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.2), value: imageVisible)
                                        .padding(10)
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 28, weight: .regular))
                                            .foregroundStyle(.secondary)
                                        Text("No photo selected")
                                            .foregroundStyle(.secondary)
                                            .font(.subheadline)
                                    }
                                    .padding(32)
                                }
                            }
                        }
                        .frame(height: 220)
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("Category", selection: $category) {
                            ForEach(Category.allCases, id: \.self) { cat in
                                Text(cat.title).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)

                        Button {
                            Task { await startAnalysis() }
                        } label: {
                            Text("Analyze Color")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AccentButtonStyle())

                        if isAnalyzing {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Analyzing color…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .transition(.opacity)
                        } else if let name = detectedColorName, let color = detectedColor {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(color)
                                    .frame(width: 36, height: 24)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray5))
                                    )
                                Text(name)
                                    .font(.subheadline)
                                if let tone = detectedTone {
                                    Text(tone.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule().fill(Color(.secondarySystemBackground))
                                        )
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .cardStyle()

                    Button {
                        store.add(image: selectedImage, category: category, color: detectedColor)
                        showSaved = true
                        withAnimation { showHUD = true }
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { savePulse = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { savePulse = false }
                        }
                    } label: {
                        Text("Save Item")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryFillButtonStyle())
                    .scaleEffect(savePulse ? 0.97 : 1)
                    .disabled(detectedColorName == nil)
                    .opacity(detectedColorName == nil ? 0.6 : 1)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            .animation(.easeInOut(duration: 0.25), value: colorScheme)
            .navigationTitle("Add Clothing Item")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: MyWardrobeView()) {
                        Label("Wardrobe", systemImage: "closet")
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera) { image in
                    selectedImage = image
                    Task { await startAnalysis() }
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = uiImage
                            imageVisible = false
                            withAnimation { imageVisible = true }
                        }
                        await startAnalysis()
                    }
                }
            }
            .alert("Item saved", isPresented: $showSaved) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your clothing item was added to My Wardrobe.")
            }
            .overlay {
                SuccessHUD(title: "Saved", isShowing: $showHUD)
            }
        }
        .tint(colorScheme == .dark ? Color(hex: "E7A7B3") : Color(hex: "F2A6B3"))
    }

    @MainActor
    func startAnalysis() async {
        isAnalyzing = true
        detectedColorName = nil
        detectedColor = nil
        detectedTone = nil
        // Simulate AI engine with short delay and realistic palette
        let swatches: [(name: String, hex: String, tone: String)] = [
            ("Soft Pink", "F2A6B3", "warm"), ("Navy", "1F3A93", "cool"), ("Ivory", "F7F3E9", "neutral"),
            ("Olive", "6B8E23", "warm"), ("Sky Blue", "A1C8F0", "cool"), ("Charcoal", "36454F", "neutral"),
            ("Mustard", "F2C94C", "warm"), ("Forest", "228B22", "cool"), ("Brown", "8B4513", "warm")
        ]
        try? await Task.sleep(nanoseconds: 800_000_000)
        let pick = swatches.randomElement()!
        withAnimation(.easeInOut(duration: 0.2)) {
            detectedColorName = pick.name
            detectedColor = Color(hex: pick.hex)
            detectedTone = pick.tone
            isAnalyzing = false
        }
    }
}

enum Category: CaseIterable {
    case top, bottom, shoes, accessory
    var title: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .shoes: return "Shoes"
        case .accessory: return "Accessory"
        }
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(hex: "F2A6B3"))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(hex: "F2A6B3"))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct PrimaryFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "F2A6B3"))
                    .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.systemGray5))
                    )
            )
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.onPick(image)
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }

    var sourceType: UIImagePickerController.SourceType
    var onPick: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = sourceType
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

#Preview {
    AddItemView()
}
