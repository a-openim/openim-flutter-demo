import 'dart:async';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:get/get.dart';
import 'package:openim/pages/conversation/conversation_logic.dart';
import 'package:openim_common/openim_common.dart';

import '../../core/controller/im_controller.dart';
import '../../routes/app_navigator.dart';

class SplashLogic extends GetxController {
  final imLogic = Get.find<IMController>();
  final pushLogic = Get.find<PushController>();

  String? get userID => DataSp.userID;

  String? get token => DataSp.imToken;

  late StreamSubscription initializedSub;
  Timer? _timeoutTimer;
  bool _navigated = false;

  @override
  void onInit() {
    Logger.print('SplashLogic onInit - userID: $userID, token: ${token != null ? "exists" : "null"}');
    
    // Add timeout to handle initialization failure
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      Logger.print('SplashLogic timeout - IM SDK may not have initialized');
      _handleNavigation();
    });
    
    initializedSub = imLogic.initializedSubject.listen((value) {
      Logger.print('SplashLogic initializedSubject received: $value');
      _handleNavigation();
    });
    super.onInit();
  }

  void _handleNavigation() {
    if (_navigated) return;
    _navigated = true;
    _timeoutTimer?.cancel();
    initializedSub.cancel();
    
    if (null != userID && null != token) {
      _login();
    } else {
      AppNavigator.startLogin();
    }
  }

  _login() async {
    try {
      Logger.print('---------login---------- userID: $userID, token: $token');
      await imLogic.login(userID!, token!);
      Logger.print('---------im login success-------');
      PushController.login(
        userID!,
        onTokenRefresh: (token) {
          OpenIM.iMManager.updateFcmToken(
              fcmToken: token, expireTime: DateTime.now().add(Duration(days: 90)).millisecondsSinceEpoch);
        },
      );
      Logger.print('---------push login success----');
      final result = await ConversationLogic.getConversationFirstPage();

      AppNavigator.startSplashToMain(isAutoLogin: true, conversations: result);
    } catch (e, s) {
      IMViews.showToast('$e $s');
      await DataSp.removeLoginCertificate();
      AppNavigator.startLogin();
    }
  }

  @override
  void onClose() {
    _timeoutTimer?.cancel();
    initializedSub.cancel();
    super.onClose();
  }
}
