{{flutter_js}}
{{flutter_build_config}}

// Load this deploy's main.dart.js, never a cached older one (the build id
// is stamped in by tool/stamp_build.py).
_flutter.buildConfig.builds.forEach(function (build) {
  if (build.mainJsPath) build.mainJsPath += '?v=__BUILD_ID__';
});

// No Flutter service worker: it cached old app versions (see index.html),
// and the only service worker we want is push_sw.js for notifications.
_flutter.loader.load();
