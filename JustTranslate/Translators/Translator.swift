import Foundation

/// 统一的翻译器协议（Swift Concurrency 版本）
protocol Translator {
    /// 显示名称（用于 UI 标题）
    var name: String { get }

    /// 异步翻译方法：返回可选字符串（nil 表示无结果），遇到错误请抛出异常
    func translate(text: String) async throws -> String?
}
