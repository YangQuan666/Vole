//
//  ImageCacheConfiguration.swift
//  Vole
//

import Foundation
import Kingfisher

/// Kingfisher 图片缓存的全局配置，在 App 启动时调用一次。
enum ImageCacheConfiguration {
    /// 磁盘缓存上限：200 MB。
    ///
    /// Kingfisher 在进入后台和退出时检查上限，超出后按最近访问时间删除最旧的文件，
    /// 直到降到上限的一半。
    static let diskSizeLimit: UInt = 200 * 1024 * 1024

    static func configure() {
        let cache = ImageCache.default
        cache.diskStorage.config.sizeLimit = diskSizeLimit

        // 磁盘缓存保存服务器返回的原始文件，而不是重新编码后的数据，
        // 查看大图时可直接使用缓存文件。
        var serializer = DefaultCacheSerializer.default
        serializer.preferCacheOriginalData = true
        KingfisherManager.shared.defaultOptions.append(.cacheSerializer(serializer))

        // Kingfisher 只在进入后台和退出时清理，启动时再清理一次，
        // 避免上次异常退出后缓存超出上限。
        cache.cleanExpiredDiskCache()
        MarkdownImagePreviewFiles.removeStaleFiles()
    }
}
