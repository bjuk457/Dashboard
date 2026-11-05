import SwiftUI

/// Connect Facebook Pages and Instagram accounts and assign them to the websites.
struct MetaSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var metaToken = ""
    @State private var instagramToken = ""

    var body: some View {
        Form {
            Section {
                SecureField("Zugriffsschlüssel (Meta Business)", text: $metaToken)
                HStack {
                    Text("Lädt alle Facebook-Seiten und die damit verknüpften Instagram-Konten.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Konten laden") {
                        Task {
                            await model.connectMeta(token: metaToken)
                            metaToken = ""
                        }
                    }
                    .disabled(metaToken.isEmpty || model.isLoading)
                }
            } header: {
                Text("Facebook-Seiten und verknüpfte Instagram-Konten")
            }

            Section {
                SecureField("Instagram-Zugriffsschlüssel", text: $instagramToken)
                HStack {
                    Text("Nur für Instagram-Konten ohne verknüpfte Facebook-Seite.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Hinzufügen") {
                        Task {
                            await model.connectInstagram(token: instagramToken)
                            instagramToken = ""
                        }
                    }
                    .disabled(instagramToken.isEmpty || model.isLoading)
                }
            } header: {
                Text("Instagram-Konto einzeln")
            }

            if !model.metaAccounts.isEmpty {
                Section {
                    ForEach(model.metaAccounts) { account in
                        HStack {
                            PlatformBadge(platform: account.platform)
                            Text(account.displayName)
                            Spacer()
                            Button(role: .destructive) {
                                model.remove(account)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("Verbundene Konten")
                }
            }

            if !model.metaAccounts.isEmpty {
                Section {
                    if model.sites.isEmpty {
                        Text("Bitte zuerst mit Google anmelden, dann erscheinen hier die Websites.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.sites, id: \.self) { site in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName(for: site)).font(.headline)
                            ForEach(model.metaAccounts) { account in
                                Toggle(isOn: Binding(
                                    get: { model.isAssigned(account, to: site) },
                                    set: { model.setAssigned($0, account: account, site: site) }
                                )) {
                                    HStack(spacing: 4) {
                                        PlatformBadge(platform: account.platform)
                                        Text(account.displayName)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Welche Konten zu welcher Website gehören")
                }
            }

            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red).font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 420)
    }
}
