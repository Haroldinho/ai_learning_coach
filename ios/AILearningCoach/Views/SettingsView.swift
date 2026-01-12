import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataController: DataController
    
    @State private var userID: String = ""
    @State private var newUserID: String = ""
    @State private var showUpdateAlert = false
    @State private var isCopied = false
    
    var body: some View {
        Form {
            Section(header: Text("Account Sync"), footer: Text("To sync your progress across devices (e.g., iPhone and Mac), use the same User ID on all of them.")) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your User ID")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text(userID)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer()
                        
                        Button {
                            UIPasteboard.general.string = userID
                            withAnimation {
                                isCopied = true
                            }
                            
                            // Reset copy status after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isCopied = false
                                }
                            }
                        } label: {
                            Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundStyle(isCopied ? .green : .blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sync with another device")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    TextField("Paste User ID here", text: $newUserID)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    Button {
                        if !newUserID.isEmpty && newUserID != userID {
                            showUpdateAlert = true
                        }
                    } label: {
                        Text("Update User ID")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newUserID.isEmpty || newUserID == userID)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Application Info")) {
                HStack {
                    Text("Backend Status")
                    Spacer()
                    Circle()
                        .fill(Color.green) // You might want to bind this to actual status
                        .frame(width: 8, height: 8)
                }
                
                HStack {
                    Text("API Endpoint")
                    Spacer()
                    Text(APIService.shared.baseURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            userID = APIService.shared.currentUserID
        }
        .alert("Replace User Data?", isPresented: $showUpdateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Replace", role: .destructive) {
                updateIdentity()
            }
        } message: {
            Text("Updating your User ID will replace your current local data with the data associated with the new ID. This cannot be undone.")
        }
    }
    
    private func updateIdentity() {
        // 1. Update API Service
        APIService.shared.updateIdentity(newID: newUserID)
        
        // 2. Refresh view state
        userID = newUserID
        newUserID = ""
        
        // 3. Clear local project state so app re-fetches
        dataController.clearCurrentProject()
        
        // 4. Force a refresh of the project list (you might need to expose a method for this)
        // For now, clearing the project helps reset the UI state
        
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataController())
}
