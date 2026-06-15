// Location: InterviewApp/Features/Authentication/RegisterView.swift

import SwiftUI

struct RegisterView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var isPasswordVisible = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Success Indicator Pop-up Banner (Green Palette applied)
            if viewModel.hasSuccessfullyRegistered {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.successText)
                        .font(.system(size: 16))
                    
                    Text("Account successfully created!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.successText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.successBackground)
                .transition(.move(edge: .top))
                .animation(.easeInOut, value: viewModel.hasSuccessfullyRegistered)
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds delay
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            
            // 2. Failure Indicator Pop-up Banner (Red Palette applied)
            if viewModel.hasAuthenticationError {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.systemAlertText)
                        .font(.system(size: 16))
                    
                    Text(viewModel.errorMessage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.systemAlertText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.systemAlertBackground)
                .transition(.move(edge: .top))
                .animation(.easeInOut, value: viewModel.hasAuthenticationError)
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 40)
                    
                    // 3. Centralized Identity Header Group
                    VStack(spacing: 12) {
                        Image(systemName: "brain.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding(18)
                            .background(Studio.accentGradient,
                                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Studio.Palette.accent.opacity(0.3), radius: 10, y: 5)

                        Text("InterviewIQ")
                            .font(.studioDisplay(28))
                            .foregroundColor(.primary)

                        Text("Register to continue")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    // 4. Identity Full Name Block Component
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "person")
                                .foregroundColor(.brandGrey)
                            
                            TextField("Enter your full name", text: $viewModel.fullName)
                                .disableAutocorrection(true)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.hasAuthenticationError ? Color.systemAlertText : Color.brandGrey.opacity(0.4), lineWidth: 1)
                        )
                    }
                    
                    // 5. Communication Email Address Component
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundColor(.brandGrey)
                            
                            TextField("Enter your email address", text: $viewModel.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.hasAuthenticationError ? Color.systemAlertText : Color.brandGrey.opacity(0.4), lineWidth: 1)
                        )
                    }
                    
                    // 6. Secure Password Component Container
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundColor(.brandGrey)
                            
                            if isPasswordVisible {
                                TextField("Enter a strong password", text: $viewModel.userPassword)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Enter a strong password", text: $viewModel.userPassword)
                            }
                            
                            Button(action: {
                                isPasswordVisible.toggle()
                            }) {
                                Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                                    .foregroundColor(.brandGrey)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.hasAuthenticationError ? Color.systemAlertText : Color.brandGrey.opacity(0.4), lineWidth: 1)
                        )
                    }
                    
                    // 7. Execution Pipeline Core Control Button
                    Button {
                        Task { await viewModel.performRegistration() }
                    } label: {
                        Text(viewModel.isLoading ? "Registering..." : "Register")
                    }
                    .buttonStyle(StudioPrimaryButtonStyle(tint: viewModel.hasSuccessfullyRegistered ? Studio.Palette.scoreHigh : nil))
                    .disabled(viewModel.isLoading || viewModel.hasSuccessfullyRegistered)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // 8. Return Flow Button Link
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(.secondary)
                            
                            Text("Sign In")
                                .foregroundColor(.brandPurple)
                                .bold()
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            // Automatically hide errors when the user corrects their input
            .onChange(of: viewModel.emailAddress) { _ in
                viewModel.hasAuthenticationError = false
            }
            .onChange(of: viewModel.userPassword) { _ in
                viewModel.hasAuthenticationError = false
            }
            .onChange(of: viewModel.fullName) { _ in
                viewModel.hasAuthenticationError = false
            }
        }
        .navigationBarHidden(true)
        .background(Studio.Palette.canvas.ignoresSafeArea())
    }
}
