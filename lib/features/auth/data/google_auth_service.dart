// Design Ref: §4.9 — google_sign_in wrapper.
// Refresh token storage is delegated to the OS via google_sign_in's silent
// sign-in (Android Account Manager backed). flutter_secure_storage handles
// any additional sensitive caching we may need later (e.g., serverAuthCode).

import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;

import '../../../infrastructure/sheets/sheet_layout.dart';

class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? signIn})
      : _signIn = signIn ??
            GoogleSignIn(scopes: SheetLayout.oauthScopes);

  final GoogleSignIn _signIn;
  final _signedInController = StreamController<bool>.broadcast();
  StreamSubscription<GoogleSignInAccount?>? _accountSub;
  bool? _lastKnownSignedIn;

  /// Hot-attaches to google_sign_in's currentUser stream. Call once in main()
  /// before runApp so UI providers can react.
  void start() {
    _accountSub ??= _signIn.onCurrentUserChanged.listen((acc) {
      _lastKnownSignedIn = acc != null;
      if (!_signedInController.isClosed) {
        _signedInController.add(acc != null);
      }
    });
    // onCurrentUserChanged only fires on changes — seed the initial value
    // so StreamProvider listeners don't hang in `loading` forever when the
    // user is already signed-out (or already silently signed-in).
    unawaited(_seedInitial());
  }

  Future<void> _seedInitial() async {
    try {
      final acc = await _signIn.signInSilently(suppressErrors: true);
      final signed = acc != null || _signIn.currentUser != null;
      if (_lastKnownSignedIn != signed) {
        _lastKnownSignedIn = signed;
        if (!_signedInController.isClosed) {
          _signedInController.add(signed);
        }
      }
    } catch (_) {
      _lastKnownSignedIn ??= false;
      if (!_signedInController.isClosed) {
        _signedInController.add(false);
      }
    }
  }

  Stream<bool> watchSignedIn() async* {
    if (_lastKnownSignedIn != null) yield _lastKnownSignedIn!;
    yield* _signedInController.stream;
  }

  Future<bool> isSignedIn() => _signIn.isSignedIn();

  Future<String?> currentEmail() async {
    final acc = _signIn.currentUser ?? await _signIn.signInSilently();
    return acc?.email;
  }

  Future<bool> signIn() async {
    final acc = await _signIn.signIn();
    return acc != null;
  }

  /// Best-effort silent re-auth. Used by the background worker isolate.
  Future<bool> signInSilently() async {
    final acc = await _signIn.signInSilently();
    return acc != null;
  }

  Future<void> signOut() async {
    await _signIn.disconnect();
  }

  /// Returns an [gauth.AuthClient] for googleapis. Token auto-refreshes via
  /// the extension package. NULL if user is not signed in or scope missing.
  Future<gauth.AuthClient?> authenticatedClient() async {
    return _signIn.authenticatedClient();
  }

  Future<void> dispose() async {
    await _accountSub?.cancel();
    await _signedInController.close();
  }
}
