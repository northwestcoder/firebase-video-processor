//
//  SplashScreenView.swift
//  ThunkVideoProcessor
//
//  Created by Ty Alevizos on 4/18/25.
//

import Foundation
import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            MainContentView()
        } else {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // App icon at the top - using the logo asset
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .padding(.bottom, 40)
                    
                    // App name in the middle (smaller) - keep animation
                    Text("Thunk Video Processor")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.bottom, 40)
                        .scaleEffect(size)
                        .opacity(opacity)
                    
                    Spacer()
                    
                    // byline image at the bottom - no animation
                    Image("byline")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                }
                .onAppear {
                    withAnimation(.easeIn(duration: 1.2)) {
                        self.size = 1.0
                        self.opacity = 1.0
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}
