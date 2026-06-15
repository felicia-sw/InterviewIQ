import SwiftUI
import FirebaseAuth

// Account screen shown from either home (admin or interviewer). Displays the
// signed-in user's profile and provides Log Out. Fetches its own profile by uid
// so it stays decoupled from the home screens that present it. Studio-styled.
struct ProfileView: View {
    let userId: String

    @State private var profile: UserProfile?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private let repo = UserRepository()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Studio.Spacing.lg) {
                    if isLoading {
                        ProgressView().padding(.top, 100)
                    } else if let profile {
                        profileHeader(profile)
                        infoCard(profile)
                        logoutButton
                    } else {
                        ContentUnavailableView(
                            "Couldn't load your profile",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("Check your connection and try again.")
                        )
                        .padding(.top, 60)
                    }
                }
                .padding(Studio.Spacing.md)
            }
            .background(Studio.Palette.canvas)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            profile = try? await repo.fetchProfile(userId: userId)
            isLoading = false
        }
    }

    // MARK: - Header

    private func profileHeader(_ profile: UserProfile) -> some View {
        VStack(spacing: Studio.Spacing.md) {
            Text(profile.fullName.prefix(1).uppercased())
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(Studio.accentGradient, in: Circle())
                .shadow(color: Studio.Palette.accent.opacity(0.3), radius: 12, y: 6)

            VStack(spacing: Studio.Spacing.xs) {
                Text(profile.fullName)
                    .font(.studioDisplay(24))
                Text(profile.role.displayName)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(Studio.Palette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Studio.Palette.accent.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Studio.Spacing.lg)
    }

    // MARK: - Info card

    private func infoCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            infoRow(icon: "person", label: "Name", value: profile.fullName)
            Divider().padding(.leading, 52)
            infoRow(icon: "envelope", label: "Email", value: profile.emailAddress)
            Divider().padding(.leading, 52)
            infoRow(icon: "shield.lefthalf.filled", label: "Role", value: profile.role.displayName)
        }
        .studioCard(padding: 0)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Studio.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Studio.Palette.accent)
                .frame(width: 24)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .padding(Studio.Spacing.md)
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button(role: .destructive) {
            logout()
        } label: {
            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .buttonStyle(StudioPrimaryButtonStyle(tint: Studio.Palette.scoreLow))
        .padding(.top, Studio.Spacing.sm)
    }

    private func logout() {
        // Signing out flips Firebase's auth state; AppAuthState's listener then
        // routes the whole app back to LoginView, tearing down this sheet.
        try? Auth.auth().signOut()
    }
}
