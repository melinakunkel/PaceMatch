{{flutter_js}}
{{flutter_build_config}}

// No Flutter service worker: it cached old app versions (see index.html),
// and the only service worker we want is push_sw.js for notifications.
_flutter.loader.load();
