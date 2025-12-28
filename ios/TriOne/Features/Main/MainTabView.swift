import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }
                .tag(0)
            
            PlanView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(1)
            
            RacesView()
                .tabItem {
                    Label("Races", systemImage: "flag.fill")
                }
                .tag(2)
            
            SocialView()
                .tabItem {
                    Label("Social", systemImage: "person.2.fill")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(Theme.primary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}

