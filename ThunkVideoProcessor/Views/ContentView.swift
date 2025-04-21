import SwiftUI

struct ContentView: View {
    @StateObject private var firebaseManager = FirebaseManager()
    
    var body: some View {
        NavigationStack {
            Group {
                if firebaseManager.isSignedIn {
                    VideoListView()
                } else {
                    LoginView()
                }
            }
        }
        .environmentObject(firebaseManager)
    }
}

#Preview {
    ContentView()
} 