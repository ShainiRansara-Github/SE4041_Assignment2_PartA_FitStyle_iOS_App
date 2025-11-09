import SwiftUI

struct FooterView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("FitStyle © \(Calendar.current.component(.year, from: Date()))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

#Preview {
    FooterView()
}
