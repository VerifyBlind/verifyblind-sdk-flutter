# verifyblind_flutter

Flutter plugin for [VerifyBlind](https://verifyblind.com). It wraps the official native SDKs; it does
not reimplement them.

- Android: [`com.verifyblind:verifyblind-android:1.0.1`](https://github.com/VerifyBlind/verifyblind-sdk-android) (Maven Central)
- iOS: Swift Package [`VerifyBlind/verifyblind-sdk-ios`](https://github.com/VerifyBlind/verifyblind-sdk-ios) from 2.3.1

**[Türkçe](#türkçe) · [English](#english)**

---

## Türkçe

Uygulamanız VerifyBlind uygulamasından kullanıcıyı doğrulamasını ister ve imzalı bir sonuç alır. Sonuç
telefonda **karar için kullanılmaz**: içindeki `token`'ı sunucunuza gönderirsiniz, sunucunuz imzayı ve
sorduğu koşulu kendisi kontrol eder.

### Kurulum

```yaml
dependencies:
  verifyblind_flutter: ^0.1.0
```

Gerekenler: Flutter 3.24+, Android `minSdk 24` (Java 17), iOS 15+ ve Swift Package Manager.

Ayrıca bir sunucu tarafı gerekir (API anahtarı yalnız orada durur):

- **Başlatma ucu** (ör. `POST /api/generate`): uygulamadan `{ public_key, validations?, custom_data? }`
  alır, `X-API-Key` ekleyip VerifyBlind'a iletir ve `{ nonce }` döner. Nonce'u sorduğu koşulla birlikte
  saklar.
- **Doğrulama ucu** (ör. `POST /api/verify`): uygulamadan `{ token }` alır, imzayı doğrular, nonce'u bir
  kez kullanır ve sonucu kendi sakladığı koşula göre okur.

Ayrıntılar: [ai-integration.md](https://verifyblind.com/ai-integration.md) ve
[verifyblind-sdk-android README](https://github.com/VerifyBlind/verifyblind-sdk-android).

### Android

1. `android/app/build.gradle` içinde `minSdk` en az **24** olmalı.
2. Geri dönüş şemasını `AndroidManifest.xml`'de ana activity'ye ekleyin (Flutter'ın varsayılan
   `launchMode="singleTop"` ayarı kalsın):

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="myapp" android:host="callback" />
</intent-filter>
```

3. Aynı şemayı (`myapp`) Partner Portal'da **Ayarlar → App Return Scheme** alanına kaydedin. VerifyBlind
   yalnız şeması kayıtlı olanla eşleşen geri dönüş adresini açar; alan boşsa uygulamanıza geri dönmez.
4. Geri dönüş adresi yalnız uygulamayı öne getirir; sonucu `checkVerificationResult` ile siz sorarsınız.
   Uygulamanız Flutter'ın derin bağlantı yönlendirmesini kullanmıyorsa, `myapp://callback` adresinin
   `Navigator`'a rota olarak gitmemesi için activity içine şunu ekleyin:
   `<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />`
   (`go_router` gibi bir yönlendirici kullanıyorsanız `/callback` rotasını boş bir sayfa olarak tanımlayın.)

### iOS

1. Swift Package Manager açık olmalı (`flutter config --enable-swift-package-manager`; yeni Flutter
   sürümlerinde varsayılan). Eklenti CocoaPods ile **gelmez**, çünkü iOS SDK yalnız Swift Package olarak
   yayımlanıyor.
2. Geri dönüş şemasını `ios/Runner/Info.plist` içine ekleyin:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>myapp</string></array>
  </dict>
</array>
```

3. Partner Portal kaydı Android ile aynı (bir şema iki platformu da kapsar).
4. Android'deki 4. maddenin karşılığı: `Info.plist` içinde `FlutterDeepLinkingEnabled` = `false`.

VerifyBlind uygulaması Universal Link (`https://app.verifyblind.com/request`) ile açıldığı için
`LSApplicationQueriesSchemes` gerekmez.

### Kullanım

```dart
final vb = VerifyBlind(VerifyBlindConfig(
  partnerBackendUrl: 'https://sizin-sunucunuz.com/api',
  generateEndpoint: 'generate',
));

// 1) Başlat: geçici anahtar üretilir, nonce alınır, VerifyBlind uygulaması açılır.
final nonce = await vb.startAuthentication(
  validations: {'age': '18+'},          // gerçek uygulamada bunu sunucunuz belirlesin
  returnUrl: 'myapp://callback',
);

// 2) Uygulama öne gelince (AppLifecycleState.resumed) saniyede bir sorun:
try {
  final result = await vb.checkVerificationResult(nonce); // null = henüz bitmedi
  if (result != null) {
    // 3) Kararı SUNUCU verir: token'ı gönderin.
    await http.post(Uri.parse('https://sizin-sunucunuz.com/api/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': result['token']}));
  }
} on VerifyBlindException catch (e) {
  if (e.code == VerifyBlindErrorCode.userCancelled) print(e.cancelReason);
}
```

Önemli noktalar:

- `startAuthentication` ile `checkVerificationResult` için **aynı** `VerifyBlind` nesnesini kullanın.
  Geçici anahtar çifti yerel tarafta bu nesneye bağlı bellekte durur; uygulama süreci kapanırsa kaybolur
  ve doğrulama yeniden başlatılmalıdır.
- Yalnız ön planda sorun (öne gelince başlatın, arka plana geçince durdurun). Arka planda yapılan istekler
  bazı cihazlarda ağ hatası verir.
- **Kararı telefonda vermeyin.** `result` içindeki `validations` yalnız gösterim içindir. Sunucunuz
  `token`'ı doğrulamadan kullanıcıyı doğrulanmış saymayın.
- `user_id`, `nsbd_id`, `doc_id` takma adlı kişisel veridir; loglamayın, sunucunuzda diğer kullanıcı
  verileri gibi koruyun.

Hata kodları (`VerifyBlindErrorCode`): `networkError`, `partnerBackendError`, `invalidResponse`,
`appLinkFailed`, `userCancelled` (+ `cancelReason`: `user_cancelled`, `no_card_registered`,
`user_declined`, `fingerprint_failed`, `session_expired`), `cryptoError` (yalnız iOS), `invalidArgument`,
`unknown`. `message` alanı yerel SDK'nın Türkçe geliştirici metnidir; son kullanıcıya olduğu gibi
göstermeyin.

### Örnek uygulama

`example/` klasöründe tek ekranlı bir uygulama var: düğme → VerifyBlind açılır → geri dönünce sonucu sorar
→ `token`'ı `https://test.verifyblind.com/api/verify` adresine gönderir → "sunucu doğruladı" ya da hatayı
gösterir. Test sunucusunun kayıtlı geri dönüş şeması `verifyblinddemo`'dur.

```
cd example
flutter run
```

---

## English

Your app asks the VerifyBlind app to verify the user and gets a signed result back. The result is **not
for deciding on the phone**: send its `token` to your server, and your server checks the signature and
the condition it asked for.

### Install

```yaml
dependencies:
  verifyblind_flutter: ^0.1.0
```

Requirements: Flutter 3.24+, Android `minSdk 24` (Java 17), iOS 15+ with Swift Package Manager.

You also need a server side (the API key lives only there):

- **Start endpoint** (e.g. `POST /api/generate`): receives `{ public_key, validations?, custom_data? }`
  from the app, adds `X-API-Key`, forwards it to VerifyBlind and returns `{ nonce }`. It stores the nonce
  together with the condition it asked.
- **Verify endpoint** (e.g. `POST /api/verify`): receives `{ token }`, verifies the signature, uses the
  nonce once and reads the result against the condition it stored.

Details: [ai-integration.md](https://verifyblind.com/ai-integration.md) and the
[verifyblind-sdk-android README](https://github.com/VerifyBlind/verifyblind-sdk-android).

### Android

1. Set `minSdk` to at least **24** in `android/app/build.gradle`.
2. Add the return scheme to your main activity in `AndroidManifest.xml` (keep Flutter's default
   `launchMode="singleTop"`):

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="myapp" android:host="callback" />
</intent-filter>
```

3. Register the same scheme (`myapp`) in the Partner Portal under **Settings → App Return Scheme**.
   VerifyBlind only opens a return URL whose scheme matches the registered one; if the field is empty it
   does not return to your app.
4. The return link only brings your app to the front; you read the result with `checkVerificationResult`.
   If your app does not use Flutter's deep-link routing, add this inside the activity so
   `myapp://callback` is not pushed to the `Navigator` as a route:
   `<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />`
   (with a router such as `go_router`, define a no-op `/callback` route instead.)

### iOS

1. Swift Package Manager must be on (`flutter config --enable-swift-package-manager`; the default in
   newer Flutter versions). The plugin is **not** available through CocoaPods, because the iOS SDK is
   published only as a Swift Package.
2. Add the return scheme to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>myapp</string></array>
  </dict>
</array>
```

3. The Partner Portal entry is the same as for Android (one scheme covers both platforms).
4. Same as Android step 4: set `FlutterDeepLinkingEnabled` to `false` in `Info.plist`.

The VerifyBlind app is opened with a Universal Link (`https://app.verifyblind.com/request`), so
`LSApplicationQueriesSchemes` is not needed.

### Usage

```dart
final vb = VerifyBlind(VerifyBlindConfig(
  partnerBackendUrl: 'https://your-server.com/api',
  generateEndpoint: 'generate',
));

// 1) Start: creates a temporary key, gets a nonce, opens the VerifyBlind app.
final nonce = await vb.startAuthentication(
  validations: {'age': '18+'},          // in a real app your server should decide this
  returnUrl: 'myapp://callback',
);

// 2) When the app is back in the foreground (AppLifecycleState.resumed), poll once a second:
try {
  final result = await vb.checkVerificationResult(nonce); // null = not finished yet
  if (result != null) {
    // 3) The SERVER decides: send the token.
    await http.post(Uri.parse('https://your-server.com/api/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': result['token']}));
  }
} on VerifyBlindException catch (e) {
  if (e.code == VerifyBlindErrorCode.userCancelled) print(e.cancelReason);
}
```

Things to know:

- Use the **same** `VerifyBlind` object for `startAuthentication` and `checkVerificationResult`. The
  temporary key pair is kept in native memory for that object; if the app process is killed it is lost and
  the verification has to be started again.
- Poll only in the foreground (start on resume, stop on pause). Background requests fail on some devices.
- **Never decide on the phone.** The `validations` in `result` are for display only. Do not treat the
  user as verified until your server has verified the `token`.
- `user_id`, `nsbd_id` and `doc_id` are pseudonymous personal data: do not log them, and protect them on
  your server like other user data.

Error codes (`VerifyBlindErrorCode`): `networkError`, `partnerBackendError`, `invalidResponse`,
`appLinkFailed`, `userCancelled` (+ `cancelReason`: `user_cancelled`, `no_card_registered`,
`user_declined`, `fingerprint_failed`, `session_expired`), `cryptoError` (iOS only), `invalidArgument`,
`unknown`. `message` is the native SDK's developer text (in Turkish); do not show it to end users as is.

### Example app

`example/` holds a one-screen app: button → VerifyBlind opens → on return it polls → sends the `token` to
`https://test.verifyblind.com/api/verify` → shows "verified by the server" or the error. The test
server's registered return scheme is `verifyblinddemo`.

```
cd example
flutter run
```

## License

Apache 2.0, see [LICENSE](LICENSE).
