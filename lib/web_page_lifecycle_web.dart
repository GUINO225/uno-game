import 'dart:async';
import 'dart:html' as html;

class WebPageLifecycleBinding {
  WebPageLifecycleBinding._({
    required StreamSubscription<html.Event> beforeUnloadSub,
    required StreamSubscription<html.Event> visibilitySub,
    required StreamSubscription<html.Event> pageHideSub,
  })  : _beforeUnloadSub = beforeUnloadSub,
        _visibilitySub = visibilitySub,
        _pageHideSub = pageHideSub;

  final StreamSubscription<html.Event> _beforeUnloadSub;
  final StreamSubscription<html.Event> _visibilitySub;
  final StreamSubscription<html.Event> _pageHideSub;

  static WebPageLifecycleBinding install(void Function(String reason) onSignal) {
    final StreamSubscription<html.Event> beforeUnloadSub =
        html.window.onBeforeUnload.listen((_) {
      onSignal('beforeunload');
    });
    final StreamSubscription<html.Event> visibilitySub =
        html.document.onVisibilityChange.listen((_) {
      if (html.document.visibilityState == 'hidden') {
        onSignal('visibility:hidden');
      }
    });
    final StreamSubscription<html.Event> pageHideSub =
        html.window.onPageHide.listen((_) {
      onSignal('pagehide');
    });

    return WebPageLifecycleBinding._(
      beforeUnloadSub: beforeUnloadSub,
      visibilitySub: visibilitySub,
      pageHideSub: pageHideSub,
    );
  }

  void dispose() {
    unawaited(_beforeUnloadSub.cancel());
    unawaited(_visibilitySub.cancel());
    unawaited(_pageHideSub.cancel());
  }
}
