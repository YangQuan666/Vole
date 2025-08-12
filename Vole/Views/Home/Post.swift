//
//  Post.swift
//  Vole
//
//  Created by 杨权 on 5/27/25.
//

import SwiftUI

struct Post: View {
    var topics: [Topic]
    var body: some View {
        List {
            ForEach(topics) { topic in
                NavigationLink {
                    //                    LandmarkDetail(landmark: landmark)
                } label: {
                    PostItem(topic: topic)
                }
            }
        }
    }
}

#Preview {
    let topics = ModelData().topics
    Post(topics: topics)
}

struct PostItem: View {
    var topic: Topic

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: topic.member?.avatarNormal ?? "")) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color("#E5E7EB"))
                    .frame(width: 50, height: 50)
            }
            VStack {
                Text(topic.member?.username ?? "Unknown")
                Text(topic.title ?? "Unknown")
            }
        }
    }
}
