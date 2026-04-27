class WebPageLifecycleBinding {
  const WebPageLifecycleBinding._();

  static WebPageLifecycleBinding install(void Function(String reason) onSignal) {
    return const WebPageLifecycleBinding._();
  }

  void dispose() {}
}
