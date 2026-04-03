import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/app_exceptions.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw const AuthException(
            message: 'Sign-in cancelled by user',
            code: 'CANCELLED'
        );
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'displayName': userCredential.user!.displayName ?? 'User',
          'email': userCredential.user!.email,
          'photoURL': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
      }

      return userCredential;

    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
          message: 'Google sign-in failed: ${e.toString()}',
          code: 'AUTH_FAILED'
      );
    }
  }

  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw AuthException(
          message: 'Sign out failed: ${e.toString()}',
          code: 'SIGN_OUT_FAILED'
      );
    }
  }
}