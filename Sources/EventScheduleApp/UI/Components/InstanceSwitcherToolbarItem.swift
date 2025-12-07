import SwiftUI

struct InstanceSwitcherToolbarItem: ToolbarContent {
    @EnvironmentObject private var instanceStore: InstanceStore

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                ForEach(instanceStore.instances) { instance in
                    Button {
                        instanceStore.setActiveInstance(instance.id)
                    } label: {
                        HStack {
                            Text(instance.displayName)
                            if instanceStore.activeInstanceID == instance.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                if let active = instanceStore.activeInstance {
                    Text(String(active.displayName.prefix(3)))
                        .font(.subheadline.monospaced())
                        .padding(6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "rectangle.3.offgrid")
                }
            }
        }
    }
}
