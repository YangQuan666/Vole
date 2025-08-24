//
//  MarkdownView.swift
//  Vole
//
//  Created by 杨权 on 8/23/25.
//

import Kingfisher
import MarkdownUI
import SwiftUI

struct MarkdownView: View {
    @State var content: String
    @State private var isRendering = true

    var body: some View {
        Markdown(content)
            .markdownInlineImageProvider(KFInlineImageProvider())
            .textSelection(.enabled)  // 开启文本选中
            .markdownTheme(.basic)
        

    }
}

struct KFInlineImageProvider: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        // 行内图常见做法：限制目标高度（点），等比下采样到这个高度
        let targetPointHeight: CGFloat = 100
        let scale = await UIScreen.main.scale
        let targetPixelSize = CGSize(
            width: targetPointHeight * scale,
            height: targetPointHeight * scale
        )
        let processor = DownsamplingImageProcessor(size: targetPixelSize)

        let result = try await KingfisherManager.shared.retrieveImage(
            with: url,
            options: [
                .processor(processor),
                .scaleFactor(scale),
                .cacheOriginalImage,
            ]
        )
        // 注意：这里必须返回 "Image" 本体，不能加修饰符
        return Image(uiImage: result.image).renderingMode(.original)
    }
}
#Preview {
    
    let str = """
                关在厨房了   \r\n后面第三第四天  就很乖了，坚持到 7 点才开始蹦跶    \r\n我起床摸摸她 带她到厨房给她喂点吃的  把卧室门关了睡回笼觉    \r\n\r\n给你们看看我的可爱小猫  \r\n![1.jpg]( https://s2.loli.net/2025/08/22/qg3FSLce4jH1TBz.jpg)\r\n![2.jpg]( https://s2.loli.net/2025/08/22/Kp3G7Yfo5EtPnFJ.jpg)\r\n![3.jpg]( https://s2.loli.net/2025/08/22/78bDXlPiEjzM2Lp.jpg)  \r\n![4.jpg]( https://s2.loli.net/2025/08/22/3KJo6mvABph5Ltx.jpg)\r\n![5.jpg]( https://s2.loli.net/2025/08/22/duAjOwcYmSFCzr4.jpg)  \r\n![6.jpg]( https://s2.loli.net/2025/08/22/pszeAWrXfk3bOUY.jpg)  \r\n![7.jpg]( https://s2.loli.net/2025/08/22/NtLBMyXhPk5Aaoz.jpg)
                """
    let content = MarkdownContent(str)
    let htmlString = content.renderHTML()
    Text(htmlString)
    ScrollView {
        MarkdownView(
//            content: """
//                    养猫的想法有一段时间了，想养一只美短起司         \r\n上个星期在小红书刷到一个同城猫舍发的可爱起司小猫视频      \r\n择日不如撞日，当即决定买下来  周六去接猫猫     \r\n超级可爱 超级乖    \r\n接回家的路上拉了臭臭 粘身上了   \r\n我帮她擦臭臭 可能有点害怕  只是想逃 不哈气不伸爪子也不咬人   \r\n擦干净放房间里就躲床下   \r\n我拿逗猫棒晃晃  她就出来追逗猫棒  \r\n一天 24 小时要玩逗猫棒  人累了不想玩了 把逗猫棒放在高的地方   \r\n她爬到桌子上把逗猫棒扒拉下来  自己叼着玩   \r\n晚上会爬到床上 趴在人身上或者旁边睡觉  \r\n还在我身上踩奶  老母亲的心都要化了  \r\n\r\n到家的第一天晚上 \r\n凌晨四五点跑酷  在床上蹦跶  在人身上蹦跶  蹦一下砰一声  我忍了  \r\n第二天早上五点又开始蹦跶  我把她引到厨房  关在厨房了   \r\n后面第三第四天  就很乖了，坚持到 7 点才开始蹦跶    \r\n我起床摸摸她 带她到厨房给她喂点吃的  把卧室门关了睡回笼觉    \r\n\r\n给你们看看我的可爱小猫  \r\n![1.jpg]( https://s2.loli.net/2025/08/22/qg3FSLce4jH1TBz.jpg)\r\n![2.jpg]( https://s2.loli.net/2025/08/22/Kp3G7Yfo5EtPnFJ.jpg)\r\n![3.jpg]( https://s2.loli.net/2025/08/22/78bDXlPiEjzM2Lp.jpg)  \r\n![4.jpg]( https://s2.loli.net/2025/08/22/3KJo6mvABph5Ltx.jpg)\r\n![5.jpg]( https://s2.loli.net/2025/08/22/duAjOwcYmSFCzr4.jpg)  \r\n![6.jpg]( https://s2.loli.net/2025/08/22/pszeAWrXfk3bOUY.jpg)  \r\n![7.jpg]( https://s2.loli.net/2025/08/22/NtLBMyXhPk5Aaoz.jpg)
//                """
            
            content: """
                <h1>标题</h1>
                <strong>加粗文字</strong>
                <img src="https://example.com/image.png" />
                """
        )
    }
}
