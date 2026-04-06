import SwiftUI

struct ArchivedDayView: View {
    let dateString: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.body)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(dateString)
    }
}
