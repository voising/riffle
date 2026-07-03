import SwiftUI

struct SwitcherView: View {
    @ObservedObject var model: SwitcherViewModel

    private let minListWidth: CGFloat = 320
    private let maxVisibleRows = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                            WindowRow(window: window, isSelected: index == model.selectedIndex)
                                .id(index)
                                .onTapGesture { model.onCommit?(index) }
                                .onHover { hovering in
                                    if hovering { model.selectedIndex = index }
                                }
                        }
                    }
                }
                .frame(height: rowsHeight)
                .onChange(of: model.selectedIndex) { newIndex in
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newIndex)
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: minListWidth, alignment: .leading)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var header: some View {
        if let first = model.windows.first {
            HStack(spacing: 6) {
                if let icon = first.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                }
                Text(first.appName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }

    private var rowsHeight: CGFloat {
        let rowHeight: CGFloat = 30 + 2 // row + spacing
        let visible = min(model.windows.count, maxVisibleRows)
        return max(CGFloat(visible) * rowHeight - 2, rowHeight - 2)
    }
}

private struct WindowRow: View {
    let window: SwitcherWindow
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let icon = window.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            Text(window.displayTitle)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false) // size to full title, never truncate
                .foregroundColor(isSelected ? .primary : .secondary)
            Spacer(minLength: 0)
            if window.isMinimized {
                Image(systemName: "minus.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
