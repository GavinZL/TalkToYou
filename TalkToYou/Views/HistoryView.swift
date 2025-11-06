import SwiftUI

struct HistoryView: View {
    @State private var sessions: [Session] = []
    @State private var selectedSession: Session?
    @State private var showingDetail = false
    
    private let persistence = PersistenceController.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSession = session
                            showingDetail = true
                        }
                }
                .onDelete(perform: deleteSessions)
            }
            .navigationTitle("历史记录")
            .toolbar {
                EditButton()
            }
            .onAppear {
                loadSessions()
            }
            .refreshable {
                loadSessions()
            }
            .sheet(isPresented: $showingDetail) {
                if let session = selectedSession {
                    SessionDetailView(session: session)
                }
            }
        }
    }
    
    // MARK: - Methods
    private func loadSessions() {
        sessions = persistence.fetchSessions()
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            persistence.deleteSession(session)
        }
        sessions.remove(atOffsets: offsets)
    }
}

// MARK: - Session Row
struct SessionRow: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(.headline)
            
            HStack {
                Label("\(session.messageCount) 条消息", systemImage: "message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(session.updateTime.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Detail View
struct SessionDetailView: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [Message] = []
    
    private let persistence = PersistenceController.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadMessages()
            }
        }
    }
    
    private func loadMessages() {
        messages = persistence.fetchMessages(for: session.id)
    }
}

#Preview {
    HistoryView()
}
