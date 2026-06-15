// Location: InterviewApp/Features/Authentication/LoginView.swift

import SwiftUI

struct LoginView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = AuthViewModel()
    @State private var isPasswordVisible = false
    @State private var isRememberMeChecked = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Account Locked Security Warning Banner
            if viewModel.isAccountLocked {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.systemAlertText)
                        .font(.system(size: 16))
                    
                    Text(viewModel.errorMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.systemAlertText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.systemAlertBackground)
                .transition(.move(edge: .top))
            }
            
            // 2. Global Error Banner Response
            if viewModel.hasAuthenticationError && !viewModel.isAccountLocked {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
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
                    
                    // 3. Centralized Brand Identifier
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
                        
                        Text("Sign in to continue")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    // 4. Email Input Structural Group
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
                    
                    // 5. Password Input Structural Group
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                Task { await viewModel.sendPasswordReset() }
                            }) {
                                Text("Forgot?")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.brandPurple)
                            }
                            .disabled(viewModel.isLoading)
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundColor(.brandGrey)
                            
                            if isPasswordVisible {
                                TextField("Enter your password", text: $viewModel.userPassword)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Enter your password", text: $viewModel.userPassword)
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
                    
                    // 6. Custom Keep Me Session Anchor Toggle
                    HStack(spacing: 8) {
                        Button(action: {
                            isRememberMeChecked.toggle()
                        }) {
                            Image(systemName: isRememberMeChecked ? "checkmark.square.fill" : "square")
                                .foregroundColor(isRememberMeChecked ? .brandPurple : .brandGrey)
                                .font(.system(size: 20))
                        }
                        
                        Text("Remember me")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    // 7. Interactive Processing Button
                    Button {
                        Task { await viewModel.performLogin() }
                    } label: {
                        Text(viewModel.isLoading ? "Signing In..." : "Login")
                    }
                    .buttonStyle(StudioPrimaryButtonStyle(tint: viewModel.isAccountLocked ? Color.brandGrey : nil))
                    .disabled(viewModel.isLoading || viewModel.isAccountLocked)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // 8. Onboarding Navigation Pivot Point
                    NavigationLink(destination: RegisterView()) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.secondary)
                            
                            Text("Register")
                                .foregroundColor(.brandPurple)
                                .bold()
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            // Add these to instantly clear errors/locks when user types a new email
            .onChange(of: viewModel.emailAddress) { _ in
                viewModel.isAccountLocked = false
                viewModel.hasAuthenticationError = false
            }
            .onChange(of: viewModel.userPassword) { _ in
                viewModel.hasAuthenticationError = false
            }
        }
        .navigationBarHidden(true)
        .background(Studio.Palette.canvas.ignoresSafeArea())
        .alert("Check your email", isPresented: $viewModel.showPasswordResetConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.passwordResetMessage)
        }
    }
}
