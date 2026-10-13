import Foundation
import Security

/// The Notion API key in the login keychain. The key MUST NOT be stored anywhere else.
enum Keychain {
  struct Failure: Error {
    let status: OSStatus
  }

  private static var item: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "dev.local.StudyTimer",
      kSecAttrAccount as String: "notion-api-key",
    ]
  }

  static func read() -> String? {
    var query = item
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func save(_ key: String) throws {
    let data = Data(key.utf8)
    var status = SecItemUpdate(
      item as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var add = item
      add[kSecValueData as String] = data
      status = SecItemAdd(add as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw Failure(status: status) }
  }
}
