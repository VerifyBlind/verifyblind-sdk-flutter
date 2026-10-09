## 0.1.0

- First version. Wraps `com.verifyblind:verifyblind-android:1.0.1` (Android) and the
  `VerifyBlind/sdk-ios` Swift Package from 2.3.1 (iOS, Swift Package Manager only).
- `VerifyBlind(config)`: `startAuthentication`, `checkVerificationResult` (result includes the signed
  `token` for your server), `dispose`.
- `VerifyBlindException` with `code` and `cancelReason`.
