import 'package:buff_lisa/data/service/global_data_service.dart';
import 'package:buff_lisa/features/auth/data/login_service.dart';
import 'package:buff_lisa/features/web/presentation/show_web.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class Auth extends ConsumerStatefulWidget  {

  const Auth({super.key});

  @override
  ConsumerState<Auth> createState() => _AuthState();

}

class _AuthState extends ConsumerState<Auth> {

  @override
  Widget build(BuildContext context) {
    final global = ref.watch(globalDataServiceProvider);
    final loginService = ref.watch(loginServiceProvider);
    return FlutterLogin(
      logo: const AssetImage('assets/icon/logo-rounded-corners.png'),
      termsOfService: [
        TermOfService(id: "0", text: "Terms of Service", mandatory: true, linkUrl: "${global.host}/public/agb"),
        TermOfService(id: "1", text: "Privacy Policy", mandatory: true, linkUrl: "${global.host}/public/privacy-policy"),
      ],
      onLogin: loginService.authUser,
      onSignup: loginService.signupUser,
      userType: LoginUserType.name,
      passwordValidator: LoginService.passwordValidator,
      userValidator: LoginService.userValidator,
      onSubmitAnimationCompleted: () => loginService.handleLoginComplete(context),
      validateUserImmediately: true,
      onRecoverPassword: loginService.recoverPassword,
      messages: LoginMessages(
          recoverPasswordDescription: "Type your username here and than check your emails",
          recoverPasswordSuccess: "Check your emails for a recovery link",
      ),
      additionalSignupFields: const [UserFormField(keyName: "email", userType: LoginUserType.email)],
      theme: LoginTheme(
        primaryColor: Theme.of(context).colorScheme.primary,
        titleStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      children: [ Positioned.fill(
          child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: privacyPolicyLinkAndTermsOfService(context),
              ),
          ),
      ),],
    );
  }

  /// creates the text, that is shown at the bottom of the login screen
  /// 'Terms of Service' and 'Privacy Policy' are clickable
  /// Click opens the corresponding page of the [ShowWebWidget]
  Widget privacyPolicyLinkAndTermsOfService(BuildContext context) {
    return Text.rich(
        TextSpan(
            text: 'By continuing, you agree to our ', style: const TextStyle(
            fontSize: 16,
        ),
            children: <TextSpan>[
              TextSpan(
                  text: 'Terms of Service', style: TextStyle(
                fontSize: 16,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.onSurface,
                color: Theme.of(context).colorScheme.onSurface,
              ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = ()
                      => context.pushNamed('web', queryParameters: {'url': "${ref.watch(globalDataServiceProvider).host}/public/agb", 'title': "Terms of Service"})
              ),
              TextSpan(
                  text: ' and ', style: const TextStyle(
                  fontSize: 18,
              ),
                  children: <TextSpan>[
                    TextSpan(
                        text: 'Privacy Policy', style: TextStyle(
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      decorationColor: Theme.of(context).colorScheme.onSurface,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () 
                            => context.pushNamed('web', 
                              queryParameters: {'url': "${ref.watch(globalDataServiceProvider).host}/public/privacy-policy", 'title': "Privacy Policy"}
                            )
                        
                    ),
                  ],
              ),
            ],
        ),
    );
  }
}
