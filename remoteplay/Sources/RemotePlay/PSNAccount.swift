// SPDX-License-Identifier: AGPL-3.0-only
// PSN girişiyle Remote Play kaydı için gereken hesap kimliğini alır.
// Akış ve istemci bilgileri chiaki-ng'den (gui/include/psnaccountid.h, gui/src/psnaccountid.cpp).

import Foundation

public enum PSNAccount {
    public enum PSNError: Error { case badResponse, http(Int) }

    static let clientId = "ba495a24-818c-472b-b12d-ff231c1b5745"
    static let clientSecret = "mvaiZkRsAsI1IBkY"
    static let tokenURL = URL(string: "https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/token")!
    static let scope = "psn:clientapp referenceDataService:countryConfig.read pushNotification:webSocket.desktop.connect sessionManager:remotePlaySession.system.update"

    public static let redirectPrefix = "https://remoteplay.dl.playstation.net/remoteplay/redirect"

    /// Uygulama içi tarayıcıda açılacak Sony giriş sayfası.
    public static let authorizeURL: URL = {
        var components = URLComponents(string: "https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "service_entity", value: "urn:service-entity:psn"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectPrefix),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "request_locale", value: "en_US"),
            URLQueryItem(name: "ui", value: "pr"),
            URLQueryItem(name: "service_logo", value: "ps"),
            URLQueryItem(name: "layout_type", value: "popup"),
            URLQueryItem(name: "smcid", value: "remoteplay"),
            URLQueryItem(name: "prompt", value: "always"),
            URLQueryItem(name: "PlatformPrivacyWs1", value: "minimal"),
        ]
        return components.url!
    }()

    /// Giriş bitince tarayıcının gittiği yönlendirme adresinden tek kullanımlık kodu çıkarır.
    public static func code(fromRedirect url: URL) -> String? {
        guard url.absoluteString.hasPrefix(redirectPrefix) else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "code" }?.value
    }

    /// Kodu token'a, token'ı hesap kimliğine (8 bayt) çevirir. Token saklanmaz.
    public static func accountId(code: String) async throws -> Data {
        var tokenRequest = URLRequest(url: tokenURL)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue(basicAuth, forHTTPHeaderField: "Authorization")
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "redirect_uri", value: redirectPrefix),
        ]
        tokenRequest.httpBody = Data((form.percentEncodedQuery ?? "").utf8)
        let token = try await json(for: tokenRequest)
        guard let accessToken = token["access_token"] as? String else { throw PSNError.badResponse }

        var infoRequest = URLRequest(url: tokenURL.appendingPathComponent(accessToken))
        infoRequest.setValue(basicAuth, forHTTPHeaderField: "Authorization")
        let info = try await json(for: infoRequest)
        guard let userId = info["user_id"] as? String, let bytes = accountIdBytes(userId: userId) else { throw PSNError.badResponse }
        return bytes
    }

    /// Ondalık `user_id`'yi 8 baytlık little-endian dizisine çevirir.
    static func accountIdBytes(userId: String) -> Data? {
        guard let value = UInt64(userId) else { return nil }
        return withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private static var basicAuth: String {
        "Basic " + Data("\(clientId):\(clientSecret)".utf8).base64EncodedString()
    }

    private static func json(for request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw PSNError.http(http.statusCode) }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw PSNError.badResponse }
        return object
    }
}
