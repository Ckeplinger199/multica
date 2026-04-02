import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor)
                    Text("Multica")
                        .font(.largeTitle.bold())
                    Text("AI-native project management")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.codeSent {
                    emailForm
                } else {
                    codeForm
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationBarHidden(true)
        }
    }

    private var emailForm: some View {
        VStack(spacing: 16) {
            TextField("Email address", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            Button {
                Task { await viewModel.sendCode() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Send Code")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.email.isEmpty || viewModel.isLoading)
        }
    }

    private var codeForm: some View {
        VStack(spacing: 16) {
            Text("Enter the 6-digit code sent to \(viewModel.email)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Verification code", text: $viewModel.code)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.monospaced())

            Button {
                Task { await viewModel.verifyCode() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.code.isEmpty || viewModel.isLoading)

            Button("Use a different email") {
                viewModel.codeSent = false
                viewModel.code = ""
                viewModel.error = nil
            }
            .font(.caption)
        }
    }
}
