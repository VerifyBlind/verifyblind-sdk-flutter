# verifyblind_flutter example

One screen: tap the button, VerifyBlind opens and asks the user to prove they are 18 or older. When
the app comes back to the foreground it polls for the result and sends the signed `token` to
`https://test.verifyblind.com/api/verify`. The screen shows "Verified by the server." only when that
server says so. Nothing from the result is shown or logged.

It uses VerifyBlind's public test backend (`https://test.verifyblind.com/api`) and the return scheme
`verifyblinddemo`, which is registered for that test partner. To try it with your own backend, change
the constants at the top of `lib/main.dart` and the scheme in `AndroidManifest.xml` / `Info.plist`.

```
flutter run
```

You need a phone with NFC and the VerifyBlind app (Google Play `com.verifyblind.mobile`, App Store
"VerifyBlind") with a registered ID card.
