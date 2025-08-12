//
//  Home.swift
//  Vexer
//
//  Created by 杨权 on 5/25/25.
//

import SwiftUI

struct HomeView: View {
    let topics = ModelData().topics

    var body: some View {
        NavigationSplitView {
            Post(topics: topics)
        } detail: {
            Text("Select a Landmark")
        }
    }
}

#Preview {
    HomeView()
}
