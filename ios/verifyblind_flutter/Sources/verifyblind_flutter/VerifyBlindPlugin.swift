import Flutter
import UIKit
import VerifyBlind

/// Thin bridge to the VerifyBlind iOS SDK (Swift Package `VerifyBlind/sdk-ios`). No crypto or
/// network code here.
///
/// One native `VerifyBlindSDK` per Dart `VerifyBlind` object (keyed by its id), kept alive between
/// `startAuthentication` and `checkVerificationResult`, because the SDK holds the temporary key
/// pair in memory. Nothing from the result is logged.
public class VerifyBlindPlugin: NSObject, FlutterPlugin {

    private static let channelName = "com.verifyblind/flutter"
    private var sdks: [Int: VerifyBlindSDK] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = VerifyBlindPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "startAuthentication":
            startAuthentication(args, result: result)
        case "checkVerificationResult":
            checkVerificationResult(args, result: result)
        case "dispose":
            if let id = Self.intArg(args["id"]) { sdks[id] = nil }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startAuthentication(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let sdk = sdkFor(args) else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "id and config.partnerBackendUrl are required", details: nil))
            return
        }
        let validations = Self.nonNull(args["validations"])
        let customData = Self.nonNull(args["customData"])
        let returnUrl = args["returnUrl"] as? String

        Task { @MainActor in
            do {
                let r = try await sdk.startAuthentication(validations: validations,
                                                          customData: customData,
                                                          returnUrl: returnUrl)
                result(r.nonce)
            } catch let e as VerifyBlindError {
                result(Self.flutterError(e))
            } catch {
                result(FlutterError(code: "UNKNOWN", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func checkVerificationResult(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let id = Self.intArg(args["id"]), let nonce = args["nonce"] as? String, !nonce.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "id and nonce are required", details: nil))
            return
        }
        // No instance → no key pair; same as the native SDK: nothing to decrypt yet.
        guard let sdk = sdks[id] else {
            result(nil)
            return
        }
        Task { @MainActor in
            do {
                let data = try await sdk.checkVerificationResult(nonce: nonce)
                result(data)
            } catch let e as VerifyBlindError {
                result(Self.flutterError(e))
            } catch {
                result(FlutterError(code: "UNKNOWN", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func sdkFor(_ args: [String: Any]) -> VerifyBlindSDK? {
        guard let id = Self.intArg(args["id"]) else { return nil }
        if let existing = sdks[id] { return existing }
        guard let c = args["config"] as? [String: Any],
              let partnerBackendUrl = c["partnerBackendUrl"] as? String,
              !partnerBackendUrl.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        let pins = (c["certificatePins"] as? [Any])?.compactMap { $0 as? String }
        let config = VerifyBlindConfig(
            partnerBackendUrl: partnerBackendUrl,
            generateEndpoint: c["generateEndpoint"] as? String ?? ".",
            verifyblindAppLinkBase: c["verifyblindAppLinkBase"] as? String ?? "https://app.verifyblind.com/request",
            verifyblindApiUrl: c["verifyblindApiUrl"] as? String ?? "https://api.verifyblind.com",
            skipSecurityChecks: c["skipSecurityChecks"] as? Bool ?? false,
            certificatePins: (pins?.isEmpty ?? true) ? nil : pins
        )
        let sdk = VerifyBlindSDK(config: config)
        sdks[id] = sdk
        return sdk
    }

    private static func flutterError(_ e: VerifyBlindError) -> FlutterError {
        var details: [String: Any] = [:]
        if let reason = e.cancelReason { details["cancelReason"] = reason }
        return FlutterError(code: e.code.rawValue, message: e.message, details: details)
    }

    private static func intArg(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let n = v as? NSNumber { return n.intValue }
        return nil
    }

    private static func nonNull(_ v: Any?) -> [String: Any]? {
        guard let m = v as? [String: Any] else { return nil }
        let filtered = m.filter { !($0.value is NSNull) }
        return filtered.isEmpty ? nil : filtered
    }
}
