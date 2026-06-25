import SwiftUI

/// Native sheet for creating a remote.
/// - Non-OAuth backends: collect credential fields, then `config create` in one shot.
/// - OAuth backends: drive rclone's `--non-interactive` state machine, presenting each
///   question (browser sign-in, then e.g. OneDrive's drive picker) as a step.
struct AddRemoteView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var providers: [Provider] = []
    @State private var selectedType = ""
    @State private var name = ""
    @State private var fieldValues: [String: String] = [:]

    // Interactive stepper state (OAuth backends).
    @State private var step: ConfigStep?
    @State private var answer = ""
    @State private var partialCreated = false   // a partial remote exists → clean up on cancel

    @State private var isWorking = false
    @State private var error: String?
    @State private var task: Task<Void, Never>?

    private var provider: Provider? { providers.first { $0.name == selectedType } }
    private var inStepper: Bool { step?.option != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if let option = step?.option {
                stepBody(option)
            } else {
                formBody
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout).padding(.horizontal).padding(.bottom, 8)
            }
            Divider()
            footer
        }
        .frame(width: 480, height: 460)
        .task { await loadProviders() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 24)).foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text("Add Remote").font(.headline)
                Text(inStepper ? "Configuring “\(name)”…" : "Configure a new rclone drive")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding()
    }

    // MARK: Form mode (type + name + intro/credentials)

    private var formBody: some View {
        Form {
            Section {
                TextField("Name", text: $name, prompt: Text("my-drive")).disabled(isWorking)
                Picker("Type", selection: $selectedType) {
                    ForEach(providers) { Text($0.description).tag($0.name) }
                }
                .disabled(isWorking)
                .onChange(of: selectedType) { fieldValues = [:] }
            }
            if let provider {
                if provider.isOAuth {
                    Section("Sign-in required") {
                        Label("This drive uses your web browser to sign in. After you "
                            + "authorize, a few quick questions may follow.",
                              systemImage: "globe")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                } else {
                    credentialSection(provider)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func credentialSection(_ provider: Provider) -> some View {
        Section("Credentials") {
            if provider.credentialFields.isEmpty {
                Text("No required fields — this remote works with defaults.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(provider.credentialFields) { option in
                if option.isPassword == true {
                    SecureField(option.name, text: binding(for: option.name))
                } else {
                    TextField(option.name, text: binding(for: option.name))
                }
            }
        }
    }

    // MARK: Stepper mode (one rclone question at a time)

    private func stepBody(_ option: ConfigOption) -> some View {
        Form {
            Section {
                if let help = option.help, !help.isEmpty {
                    Text(help).font(.callout).foregroundStyle(.secondary)
                }
                inputField(option)
            } header: {
                Text(option.name)
            } footer: {
                if option.required { Text("Required").font(.caption) }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func inputField(_ option: ConfigOption) -> some View {
        if let examples = option.examples, !examples.isEmpty {
            Picker("Choice", selection: $answer) {
                ForEach(examples) { ex in
                    Text(ex.help.map { "\(ex.value) — \($0)" } ?? ex.value).tag(ex.value)
                }
            }
            .labelsHidden()
        } else if option.isBool {
            Picker("Choice", selection: $answer) {
                Text("Yes").tag("true")
                Text("No").tag("false")
            }
            .pickerStyle(.segmented).labelsHidden()
        } else if option.isSecret {
            SecureField("Value", text: $answer)
        } else {
            TextField("Value", text: $answer)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if isWorking {
                ProgressView().controlSize(.small)
                Text(inStepper || step != nil
                     ? "Working… a browser window may open to sign in"
                     : "Working…")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { cancel() }.keyboardShortcut(.cancelAction)
            if inStepper {
                Button("Continue") { task = Task { await submit() } }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabled(isWorking)
            } else {
                Button(provider?.isOAuth == true ? "Authorize & Create" : "Create") {
                    task = Task { await primaryAction() }
                }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(isWorking || name.isEmpty || selectedType.isEmpty)
            }
        }.padding()
    }

    // MARK: Actions

    private func loadProviders() async {
        guard providers.isEmpty else { return }
        do {
            providers = try await app.backend.providers()
                .sorted { $0.description.localizedStandardCompare($1.description) == .orderedAscending }
            selectedType = providers.first { $0.name == "drive" }?.name
                ?? providers.first?.name ?? ""
        } catch { self.error = error.localizedDescription }
    }

    private func primaryAction() async {
        if provider?.isOAuth == true { await startOAuth() } else { await createCredential() }
    }

    private func createCredential() async {
        guard let provider else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        do {
            try await app.backend.createRemote(
                name: name, type: provider.name,
                options: fieldValues.filter { !$0.value.isEmpty })
            await finishSuccess()
        } catch { self.error = error.localizedDescription }
    }

    private func startOAuth() async {
        guard let provider else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        do {
            let first = try await app.backend.configStart(name: name, type: provider.name)
            partialCreated = true
            await advance(to: first)
        } catch { self.error = error.localizedDescription }
    }

    private func submit() async {
        guard let current = step, current.option != nil else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        do {
            let next = try await app.backend.configContinue(
                name: name, state: current.state, result: answer)
            await advance(to: next)
        } catch { self.error = error.localizedDescription }
    }

    private func advance(to next: ConfigStep) async {
        if !next.error.isEmpty { error = next.error; return }
        if next.isComplete { await finishSuccess(); return }
        step = next
        answer = prefill(for: next.option!)
    }

    private func finishSuccess() async {
        partialCreated = false
        await app.loadRemotes()
        if let new = app.remotes.first(where: { $0.name == name }) { app.selection = .remote(new) }
        dismiss()
    }

    private func cancel() {
        task?.cancel()
        if partialCreated {
            let backend = app.backend
            let remoteName = name
            Task { try? await backend.deleteRemote(name: remoteName) }   // remove the partial
        }
        dismiss()
    }

    // MARK: Helpers

    private func prefill(for option: ConfigOption) -> String {
        if let d = option.defaultStr, !d.isEmpty { return d }
        if let first = option.examples?.first?.value { return first }
        return option.isBool ? "true" : ""
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { fieldValues[key] ?? "" }, set: { fieldValues[key] = $0 })
    }
}
