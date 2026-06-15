import SwiftUI
import FirebaseAuth

@Observable
private final class AppAuthState {
    var isLoggedIn: Bool
    var currentUserId: String

    var profile: UserProfile?
    var isLoadingProfile: Bool = false
    var profileLoadFailed: Bool = false

    private let userRepository = UserRepository()
    private var listenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        let currentUser = Auth.auth().currentUser
        isLoggedIn = currentUser != nil
        currentUserId = currentUser?.uid ?? ""
        // Show spinner immediately so ContentView never flashes "Couldn't Load Account"
        // before the auth listener fires.
        isLoadingProfile = currentUser != nil

        // Firebase guarantees this listener fires immediately on registration with the
        // current auth state, so this is the single authoritative place that calls
        // loadProfile. A second call from init would cause isLoadingProfile to bounce
        // true→false→true→false, remounting SessionDashboardView and cancelling its
        // .task before the session fetch completes.
        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoggedIn = user != nil
                self.currentUserId = user?.uid ?? ""
                if let uid = user?.uid {
                    Task { await self.loadProfile(uid: uid) }
                } else {
                    self.profile = nil
                    self.isLoadingProfile = false
                    self.profileLoadFailed = false
                }
            }
        }
    }

    @MainActor
    func loadProfile(uid: String) async {
        isLoadingProfile = true
        profileLoadFailed = false
        defer { isLoadingProfile = false }
        do {
            profile = try await userRepository.fetchProfile(userId: uid)
            profileLoadFailed = (profile == nil)
        } catch {
            profile = nil
            profileLoadFailed = true
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    deinit {
        if let handle = listenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

struct ContentView: View {
    @State private var authState = AppAuthState()

    // First-run welcome, shown once after the first successful login.
    @AppStorage("studio.hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        if !authState.isLoggedIn {
            NavigationView {
                LoginView()
            }
        } else if authState.isLoadingProfile {
            ProgressView("Loading your account…")
        } else if let profile = authState.profile, profile.isActive {
            // All authenticated users go to the unified session dashboard (Q1-B).
            // Session ownership is determined per-session, not by a global role.
            // First launch shows a one-time, role-aware welcome.
            if hasSeenWelcome {
                SessionDashboardView(
                    viewModel: SessionDashboardVM(userId: profile.userId)
                )
            } else {
                WelcomeView(profile: profile) {
                    withAnimation(.easeInOut) { hasSeenWelcome = true }
                }
            }
        } else if authState.profile?.isActive == false {
            accountIssue(
                title: "Account Deactivated",
                message: "Your account has been deactivated. Please contact your administrator."
            )
        } else {
            accountIssue(
                title: "Couldn't Load Account",
                message: "We couldn't load your profile. Check your connection and try again."
            )
        }
    }

    private func accountIssue(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign Out") { authState.signOut() }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}
