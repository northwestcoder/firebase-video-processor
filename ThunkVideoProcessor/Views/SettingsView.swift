import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var webhookURL: String = ""
    @State private var showSaveConfirmation = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            NavigationView {
                Form {
                    Section(header: Text("Thunk.AI Configuration")) {
                        VStack(alignment: .leading) {
                            Text("Webhook URL")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            TextEditor(text: $webhookURL)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(AppColors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(.vertical, 4)
                        
                        Text("This URL is used to send video data to Thunk.AI for processing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .listRowBackground(AppColors.background)
                    
                    Section(header: Text("Debug Options")) {
                        Toggle("Enable Debug Output", isOn: $settingsManager.debugOutputEnabled)
                    }
                    .listRowBackground(AppColors.background)
                    
                    Section {
                        Button("Save") {
                            settingsManager.webhookURL = webhookURL
                            showSaveConfirmation = true
                        }
                        .disabled(webhookURL.isEmpty)
                        
                        Button(role: .destructive, action: {
                            settingsManager.resetToDefaults()
                            webhookURL = settingsManager.webhookURL
                        }) {
                            Text("Reset to Defaults")
                        }
                    }
                    .listRowBackground(AppColors.background)
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
                .navigationTitle("Settings")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        dismiss()
                    }
                )
                .alert("Settings Saved", isPresented: $showSaveConfirmation) {
                    Button("OK") {
                        dismiss()
                    }
                } message: {
                    Text("Your Thunk.AI webhook URL has been saved.")
                }
                .onAppear {
                    webhookURL = settingsManager.webhookURL
                }
            }
            .background(AppColors.background)
        }
    }
}

#Preview {
    SettingsView()
} 