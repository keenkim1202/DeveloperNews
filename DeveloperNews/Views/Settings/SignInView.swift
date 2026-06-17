import SwiftUI

struct SignInView: View {
    private let appState: AppState

    @Bindable private var viewModel: SignInViewModel

    @Environment(\.dismiss) private var dismiss

    init(
        appState: AppState,
        viewModel: SignInViewModel,
    ) {
        self.appState = appState
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    termsCheckbox

                    VStack(spacing: 12) {
                        Button(action: signInWithApple) {
                            HStack(spacing: 8) {
                                Image(.appleLogo)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(.authSignInWithApple)
                                    .font(.dsButton)
                                    .foregroundStyle(DSColor.scrim)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DSColor.onAccent)
                                    .stroke(DSColor.accent, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.hasAgreedToTerms)
                        .opacity(viewModel.hasAgreedToTerms ? 1 : 0.5)

                        Button(action: signInWithGoogle) {
                            HStack(spacing: 8) {
                                Image(.googleLogo)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(.authSignInWithGoogle)
                                    .font(.dsButton)
                                    .foregroundStyle(DSColor.scrim)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DSColor.onAccent)
                                    .stroke(DSColor.accent, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.hasAgreedToTerms)
                        .opacity(viewModel.hasAgreedToTerms ? 1 : 0.5)
                    }

                    dividerWithText(.authOr)

                    VStack(spacing: 12) {
                        TextField(.authEmail, text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(12)
                            .background {
                                DSColor.surface
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        if viewModel.showEmailFormatError {
                            Text("auth.error.invalidEmail")
                                .font(.footnote)
                                .foregroundStyle(DSColor.destructive)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        SecureField(.authPassword, text: $viewModel.password)
                            .textContentType(viewModel.isSignUp ? .newPassword : .password)
                            .padding(12)
                            .background {
                                DSColor.surface
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button(action: submitEmailForm) {
                            Text(viewModel.isSignUp ? .authCreateAccount : .authSignInWithEmail)
                                .font(.dsButton)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(DSColor.onAccent)
                                .background {
                                    DSColor.accent
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(!viewModel.canSubmitEmailForm)

                        if !viewModel.isSignUp {
                            Button(action: openPasswordReset) {
                                Text("auth.forgotPassword")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(action: toggleSignUpMode) {
                            Text(viewModel.isSignUp ? .authAlreadyHaveAccount : .authNoAccount)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(DSColor.destructive)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .overlay {
                if viewModel.isLoading {
                    DSColor.scrim.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil)
            }
            .navigationTitle(.authSignIn)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
            .sheet(isPresented: $viewModel.showPasswordReset) {
                PasswordResetView(appState: appState)
            }
            .sheet(isPresented: $viewModel.showPrivacyPolicy) {
                NavigationStack { PrivacyPolicyView() }
            }
            .sheet(isPresented: $viewModel.showTermsOfUse) {
                NavigationStack { TermsOfUseView() }
            }
        }
    }

    private var termsCheckbox: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: toggleTermsAgreement) {
                Image(viewModel.hasAgreedToTerms ? .checkboxChecked : .checkboxUnchecked)
                    .font(.title3)
                    .foregroundStyle(viewModel.hasAgreedToTerms ? DSColor.accent : .secondary)
            }
            .buttonStyle(.plain)
            Text(termsAgreementAttributed)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .tint(DSColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "devnews" {
                        if url.host == "terms" {
                            viewModel.showTermsOfUse = true
                            return .handled
                        }
                        if url.host == "privacy" {
                            viewModel.showPrivacyPolicy = true
                            return .handled
                        }
                    }
                    return .systemAction
                })
        }
    }

    private var termsAgreementAttributed: AttributedString {
        let raw = String(localized: .authTermsAgreement)
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: raw, options: options)) ?? AttributedString(raw)
    }

    private func signInWithApple() {
        Task {
            await viewModel.signInWithApple()
            if viewModel.isSignedIn {
                dismiss()
            }
        }
    }

    private func signInWithGoogle() {
        Task {
            await viewModel.signInWithGoogle()
            if viewModel.isSignedIn {
                dismiss()
            }
        }
    }

    private func submitEmailForm() {
        Task {
            await viewModel.submitEmailForm()
            if viewModel.isSignedIn {
                dismiss()
            }
        }
    }

    private func openPasswordReset() {
        viewModel.openPasswordReset()
    }

    private func toggleSignUpMode() {
        viewModel.toggleMode()
    }

    private func toggleTermsAgreement() {
        viewModel.hasAgreedToTerms.toggle()
    }

    private func cancel() {
        dismiss()
    }

    private func dividerWithText(_ text: LocalizedStringResource) -> some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
    }
}


struct PasswordResetView: View {
    @State private var viewModel: PasswordResetViewModel

    @State private var email = ""
    @State private var successMessage: String?

    @Environment(\.dismiss) private var dismiss

    init(appState: AppState) {
        _viewModel = State(initialValue: PasswordResetViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("auth.passwordReset.description")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField(.authEmail, text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background {
                        DSColor.surface
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(action: sendPasswordReset) {
                    Text("auth.passwordReset.send")
                        .font(.dsButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(DSColor.onAccent)
                        .background {
                            DSColor.accent
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!viewModel.canSubmit(email: email))

                if let successMessage {
                    Text(successMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.leading)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(DSColor.destructive)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("auth.passwordReset.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil)
            }
            .overlay {
                if viewModel.isLoading {
                    DSColor.scrim.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
        }
    }

    private func sendPasswordReset() {
        Task {
            successMessage = nil
            let didSucceed = await viewModel.sendPasswordReset(email: email)
            if didSucceed {
                successMessage = String(localized: .authPasswordResetSuccess)
            }
        }
    }

    private func cancel() {
        viewModel.clearError()
        dismiss()
    }
}
