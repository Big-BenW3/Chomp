/// GitHub OAuth authentication service.
///
/// Handles the complete OAuth flow using FlutterWebAuth2:
/// 1. Opens GitHub's consent screen in the system browser
/// 2. Captures the OAuth callback with the authorization code
/// 3. Exchanges the code with our backend for a Chomp session token
///
/// Security note: The raw GitHub access token never touches the client.
/// The backend exchanges it securely and returns a Chomp JWT instead.

library;

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../core/env.dart';
import '../core/constants.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final _api = ApiClient.instance;

  /// Initiates GitHub OAuth flow and returns the authenticated user.
  ///
  /// Opens the system browser to GitHub's OAuth authorization page.
  /// After the user authorizes, GitHub redirects to our custom URL
  /// scheme with an authorization code, which we exchange with our
  /// backend for a session token.
  ///
  /// Throws [StateError] if GitHub doesn't return an authorization code.
  Future<ChompUser> signInWithGitHub() async {
    // Build GitHub OAuth authorization URL
    //
    // Scope note: classic GitHub OAuth has no read-only scope that
    // covers private repos — `public_repo` would silently hide every
    // private repository, which are half the point of scanning. `repo`
    // grants more access than strictly needed, but it's the only way
    // to see private repos; the token lives only on our backend (AES
    // encrypted), never on the device.
    final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': Env.githubClientId,
      'scope': 'repo read:user',
      'redirect_uri': '${Env.githubCallbackScheme}://callback',
    });

    // Open system browser and wait for callback
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: Env.githubCallbackScheme,
    );

    // Extract authorization code from callback URL
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) {
      throw StateError('GitHub did not return an authorization code.');
    }

    // Exchange code with our backend for a session token
    final response =
        await _api.post(ApiEndpoints.githubOAuthExchange, {'code': code})
            as Map<String, dynamic>;
    final sessionToken = response['session_token'] as String;
    await _api.setSessionToken(sessionToken);
    return ChompUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// Checks if the user is currently signed in.
  ///
  /// Returns true if a session token exists in secure storage.
  /// Note: This doesn't validate the token's expiration — that's
  /// handled by the backend on each request.
  Future<bool> isSignedIn() async => (await _api.sessionToken) != null;

  /// Fetches the current authenticated user's profile from the backend.
  ///
  /// Calls GET /me using the stored session token. Returns null if
  /// the token is expired or the request fails.
  Future<ChompUser?> getCurrentUser() async {
    try {
      final response = await _api.get(ApiEndpoints.me) as Map<String, dynamic>;
      return ChompUser.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Signs the user out: revokes the session server-side, then clears
  /// the local token. Server revocation bumps token_version so lost or
  /// cloned JWTs are dead on arrival, and removes this device from the
  /// push list. Best-effort — local sign-out always proceeds.
  Future<void> signOut() async {
    try {
      await _api.post('/auth/disconnect', {});
    } catch (_) {
      // Network/cache issues must not strand the user signed in.
    }
    await _api.clearSession();
  }
}
