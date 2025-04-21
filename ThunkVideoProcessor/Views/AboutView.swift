//
//  AboutView.swift
//  ThunkVideoProcessor
//
//  Created by Ty Alevizos on 4/18/25.
//

import Foundation
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 256/255, green: 252/255, blue: 228/255)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("About Thunk Video Processor")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                                
                    Text("Features:")
                        .font(.headline)
                        .padding(.top, 10)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "video.fill", text: "Record videos directly from your device")
                        FeatureRow(icon: "arrow.up.circle.fill", text: "Upload videos to Firebase")
                        FeatureRow(icon: "square.and.arrow.up", text: "Send secure video URL to Thunk for processing!")
                    }
                    
                    Spacer()
                    
                    Text("Version v1.02")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .navigationBarItems(trailing: Button(action: {
            dismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
        })
    }
}
