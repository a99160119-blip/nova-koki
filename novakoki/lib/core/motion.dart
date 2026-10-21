import 'package:flutter/widgets.dart';

import '../state/app_scope.dart';

/// True when animations should be minimal: the OS "remove animations" setting
/// or the in-app "Reduce motion" setting.
bool reduceMotion(BuildContext context) {
  return MediaQuery.of(context).disableAnimations ||
      AppScope.of(context).settings.reducedMotion;
}
