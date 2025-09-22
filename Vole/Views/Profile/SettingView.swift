//
//  SettingView.swift
//  Vole
//
//  Created by 杨权 on 9/22/25.
//

import SwiftUI

struct SettingView: View {

    var body: some View {
        List {
            Section {
                HStack {
                    Text("主题色")
                    Spacer()
                    Text("蓝色")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section {
                HStack {
                    Text("版本号") //点击跳转app store
                    Spacer()
                    Text("v0.0.1")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    
                    Text("请我喝咖啡")
                    Spacer()
                    Label("为爱发电感谢支持", systemImage: "cup.and.saucer.fill")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            

            // 关于
            Section {
                HStack {
                    Text("联系我们")
                    Spacer()
                    Text("token")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("许可协议")
                    Spacer()
                    Text("token")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("开源软件声明")
                    Spacer()
                    Text("token")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingView()
}
