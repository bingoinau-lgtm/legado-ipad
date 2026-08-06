import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let isSuccess: Bool
    let errorMsg: String?
    let data: T?
}

struct APIEmptyData: Decodable {}

enum LegadoAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "服务器地址无效"
        case .invalidResponse:
            return "服务器返回异常"
        case .server(let message):
            return message.isEmpty ? "请求失败" : message
        case .decoding(let error):
            return "数据解析失败：\(error.localizedDescription)"
        case .transport(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}
