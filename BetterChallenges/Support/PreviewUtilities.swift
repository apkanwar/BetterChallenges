#if DEBUG
import SwiftUI

struct PreviewBindingContainer<Value, Content: View>: View {
    @State private var value: Value
    private let contentBuilder: (Binding<Value>) -> Content

    init(_ initialValue: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initialValue)
        self.contentBuilder = content
    }

    var body: some View {
        contentBuilder($value)
    }
}
#endif
