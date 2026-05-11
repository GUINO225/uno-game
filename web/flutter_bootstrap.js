{{flutter_js}}
{{flutter_build_config}}

const loading = document.getElementById('app-loading');

function setLoadingText(message) {
  if (!loading) {
    return;
  }
  const label = loading.querySelector('div:last-child');
  if (label) {
    label.textContent = message;
  }
}

function hideLoading() {
  if (!loading) {
    return;
  }
  loading.classList.add('hidden');
  setTimeout(() => loading.remove(), 260);
}

window.addEventListener('flutter-first-frame', hideLoading, { once: true });

_flutter.loader.load({
  config: {},
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      setLoadingText('Initialisation...');
      const appRunner = await engineInitializer.initializeEngine();
      setLoadingText('Ouverture du jeu...');
      await appRunner.runApp();
    } catch (error) {
      console.error(error);
      setLoadingText('Chargement impossible. Rechargez la page.');
    }
  },
});
