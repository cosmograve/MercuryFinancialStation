import SwiftUI

struct ScreenHeaderView: View {
    let topTitle: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(topTitle)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.tabUnselected)

            Text(title)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 24)
        .padding(.top, 24)
    }
}
