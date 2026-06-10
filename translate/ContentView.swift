//
//  ContentView.swift
//  translate
//

import SwiftUI

struct ContentView: View {
    @State private var settingsVM = SettingsViewModel()
    
    var body: some View {
        TabView {
            HomeView(settingsVM: settingsVM)
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
            
            ProfileView(settingsVM: settingsVM)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
        }
        .preferredColorScheme(.dark) // 强制深色模式
        .tint(settingsVM.currentTheme.colors[0]) // Tab 选中颜色
    }
}

#Preview {
    ContentView()
}

