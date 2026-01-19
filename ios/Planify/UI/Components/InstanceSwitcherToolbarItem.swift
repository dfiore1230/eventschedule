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
                            VStack(alignment: .leading) {
                                Text(instance.displayName)
                                if let host = instance.baseURL.host {
                                    Text(host)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if instanceStore.activeInstanceID == instance.id {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                }
                
                Divider()
                
                if instanceStore.instances.count > 1 {
                    Text("\(instanceStore.instances.count) servers connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack(spacing: 4) {
                    if let active = instanceStore.activeInstance {
                        Text(String(active.displayName.prefix(3)))
                            .font(.subheadline.monospaced().weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                    } else {
                        Image(systemName: "server.rack")
                    }
                    
                    if instanceStore.instances.count > 1 {
                        Text("\(instanceStore.instances.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
}
