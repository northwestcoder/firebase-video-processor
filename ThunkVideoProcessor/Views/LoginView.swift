import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var firebaseManager: FirebaseManager
    @State private var showError = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer()
                            .frame(height: geometry.size.height * 0.05)
                        
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: min(geometry.size.width * 0.2, 100)))
                            .foregroundColor(.blue)
                        
                        Text("Welcome to Thunk Video Processor")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("Sign in to access your videos")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button(action: {
                            Task {
                                do {
                                    try await firebaseManager.signIn()
                                } catch {
                                    firebaseManager.error = error
                                    showError = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                Text("Sign in with Google")
                            }
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: min(geometry.size.width * 0.8, 400))
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.top, 20)
                        
                        Spacer()
                            .frame(height: geometry.size.height * 0.05)
                    }
                    .frame(minHeight: geometry.size.height)
                    .frame(width: geometry.size.width)
                }
                .scrollDisabled(true)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                firebaseManager.error = nil
            }
        } message: {
            if let error = firebaseManager.error {
                Text(error.localizedDescription)
            } else {
                Text("Unknown error")
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(FirebaseManager())
} 
