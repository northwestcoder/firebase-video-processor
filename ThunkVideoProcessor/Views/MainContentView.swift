//
//  MainContentView.swift
//  ThunkVideoProcessor
//
//  Created by Ty Alevizos on 4/18/25.
//

import Foundation
import SwiftUI
import Firebase
import GoogleSignIn

struct MainContentView: View {
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
