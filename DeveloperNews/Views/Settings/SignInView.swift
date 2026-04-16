import SwiftUI

struct SignInView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SignInViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: SignInViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    termsCheckbox

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.signInWithApple()
                                if viewModel.isSignedIn { dismiss() }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image("apple_logo")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text("auth.signInWithApple")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .stroke(Color.accentColor, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.hasAgreedToTerms)
                        .opacity(viewModel.hasAgreedToTerms ? 1 : 0.5)

                        Button {
                            Task {
                                await viewModel.signInWithGoogle()
                                if viewModel.isSignedIn { dismiss() }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image("google_logo")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text("auth.signInWithGoogle")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .stroke(Color.accentColor, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.hasAgreedToTerms)
                        .opacity(viewModel.hasAgreedToTerms ? 1 : 0.5)
                    }

                    dividerWithText("auth.or")

                    VStack(spacing: 12) {
                        TextField("auth.email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        if viewModel.showEmailFormatError {
                            Text("auth.error.invalidEmail")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        SecureField("auth.password", text: $viewModel.password)
                            .textContentType(viewModel.isSignUp ? .newPassword : .password)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            Task {
                                await viewModel.submitEmailForm()
                                if viewModel.isSignedIn { dismiss() }
                            }
                        } label: {
                            Text(viewModel.isSignUp ? LocalizedStringResource("auth.createAccount") : LocalizedStringResource("auth.signInWithEmail"))
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(.white)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(!viewModel.canSubmitEmailForm)

                        if !viewModel.isSignUp {
                            Button {
                                viewModel.openPasswordReset()
                            } label: {
                                Text("auth.forgotPassword")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            viewModel.toggleMode()
                        } label: {
                            Text(viewModel.isSignUp ? LocalizedStringResource("auth.alreadyHaveAccount") : LocalizedStringResource("auth.noAccount"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .navigationTitle("auth.signIn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
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
            Button {
                viewModel.hasAgreedToTerms.toggle()
            } label: {
                Image(systemName: viewModel.hasAgreedToTerms ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(viewModel.hasAgreedToTerms ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Text(termsAgreementAttributed)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .tint(Color.accentColor)
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
        let raw = String(localized: "auth.termsAgreement")
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: raw, options: options)) ?? AttributedString(raw)
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
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var authService: AuthService { appState.authService }

    @State private var email = ""
    @State private var successMessage: String?

    private var isEmailFormatValid: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("auth.passwordReset.description")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("auth.email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    Task {
                        successMessage = nil
                        authService.setErrorMessage(nil)
                        let result = await authService.sendPasswordReset(email: email)
                        if case .success = result {
                            successMessage = String(localized: "auth.passwordReset.success")
                        }
                    }
                } label: {
                    Text("auth.passwordReset.send")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!isEmailFormatValid || authService.isLoading)

                if let successMessage {
                    Text(successMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.leading)
                }

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("auth.passwordReset.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authService.setErrorMessage(nil)
                        dismiss()
                    }
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .overlay {
                if authService.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
        }
    }
}
