import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:string_validator/string_validator.dart';

part 'login_service.g.dart';

class LoginService {
  Ref ref;

  LoginService({required this.ref});

  /// Navigates to the NavBar Widget when authentication was successful
  void handleLoginComplete(BuildContext context) {
    Posthog().screen(screenName: "loginComplete");
    context.goNamed('home');
  }

  /// This method is called when the user tries to login with a username and password to an existing account
  /// return returns null when login was successful and an error message on errors
  Future<String?> authUser(LoginData data) async {
    try {
      return await ref.read(authServiceProvider.notifier).login(data.name, data.password);
    } catch (e) {
      await Posthog().screen(screenName: "signInFailed", properties: {"error": e.toString()});
      return "cannot connect to server";
    }
  }

  /// This method is called when a user completed the signup form and tries to signup
  /// return returns null when signup was successful and an error message on errors
  Future<String?> signupUser(SignupData data) async {
    try {
      if (data.name == null || data.password == null) {
        return "name or password ar not valid";
      } else if (!emailValidator(data.additionalSignupData!["email"])) {
        return "email does not have the correct format";
      } else {
        return await ref
            .read(authServiceProvider.notifier)
            .signupNewUser(data.name!, data.password!,
                data.additionalSignupData!["email"]!,);
      }
    } catch (e) {
      await Posthog().screen(screenName: "signupFailed", properties: {"error": e.toString()});
      return "cannot connect to server";
    }
  }

  /// This method starts the recovery process for a given existing username
  /// Returns null on a successful call to the server or an error message on errors
  Future<String?> recoverPassword(String name) {
    try {
      Posthog().screen(screenName: "recoverPassword");
      return ref.read(authServiceProvider.notifier).recover(name).then((value) {
        return value ? null : 'User does not have an email address';
      });
    } catch (e) {
      Posthog().screen(screenName: "recoverPasswordFailed", properties: {"error": e.toString()});
      return Future<String>.value("cannot connect to server");
    }

  }

  /// Validator Method for validating password
  /// returns null on success or an error message for an incorrect input
  static String? passwordValidator(String? s) {
    final alphanumeric =
        RegExp(r'^[a-zA-Z0-9!@#$%^&*(),.?":{}|<>~`/\\[\]\-_=+]*$');
    if (s == null) {
      return "input is not valid";
    } else if (s.length < 2) {
      return "at least 2 characters";
    } else if (s.length > 29) {
      return "shorter than 30 characters";
    } else if (!alphanumeric.hasMatch(s)) {
      return "includes not allowed characters";
    }
    return null;
  }

  /// Validator Method for validating password
  /// returns null on success or an error message for an incorrect input
  static String? userValidator(String? s) {
    final alphanumeric = RegExp(r'^[a-zA-Z0-9!@#$%^&*]*$');
    if (s == null) {
      return "input is not valid";
    } else if (s.length < 2) {
      return "at least 2 characters";
    } else if (s.length > 29) {
      return "shorter than 30 characters";
    } else if (!alphanumeric.hasMatch(s)) {
      return "includes not allowed characters";
    }
    return null;
  }

  /// Validator method for validating emails
  /// returns true on success or false for an incorrect input
  static bool emailValidator(String? s) {
    if (s != null && isEmail(s)) {
      return true;
    } else {
      return false;
    }
  }

  static String? emailValidatorWithErrorMessage(String? s) {
    if (s != null && isEmail(s)) {
      return null;
    } else {
      return "Is not an email";
    }
  }
}

@riverpod
LoginService loginService(Ref ref) => LoginService(ref: ref);
