(function (document, window) {
  window.posthog = window.posthog || [];
  var posthog = window.posthog;

  posthog.__SV = 1.2;
  posthog._i = posthog._i || [];

  function createQueue(instanceName) {
    var queue =
      instanceName === "posthog"
        ? posthog
        : (posthog[instanceName] = posthog[instanceName] || []);
    queue.people = queue.people || [];
    queue.toString = function (loaded) {
      var label = "posthog";
      if (instanceName !== "posthog") {
        label += "." + instanceName;
      }
      return loaded ? label : label + " (stub)";
    };
    queue.people.toString = function () {
      return queue.toString(true) + " (stub)";
    };
    return queue;
  }

  function addMethod(instance, method) {
    var parts = method.split(".");
    if (parts.length === 2) {
      instance = instance[parts[0]];
      method = parts[1];
    }
    instance[method] = function () {
      instance.push([method].concat(Array.prototype.slice.call(arguments, 0)));
    };
  }

  function addMethods(queue) {
    var methods = [
      "capture",
      "identify",
      "alias",
      "people.set",
      "people.set_once",
      "reset",
      "register",
      "unregister",
      "opt_out_capturing",
      "opt_in_capturing",
      "has_opted_out_capturing",
      "clear_opt_out_capturing",
      "get_distinct_id",
      "debug",
      "group",
      "reloadFeatureFlags",
      "setPersonProperties",
      "getFeatureFlag",
      "getFeatureFlagPayload",
      "getFeatureFlagResult",
      "get_session_id",
      "onFeatureFlags",
      "startSessionRecording",
      "stopSessionRecording",
      "sessionRecordingStarted",
    ];
    for (var index = 0; index < methods.length; index++) {
      addMethod(queue, methods[index]);
    }
  }

  addMethods(createQueue("posthog"));
  posthog.init = function (apiKey, options, name) {
    options = options || {};
    var instanceName = name || "posthog";
    var queue = createQueue(instanceName);
    addMethods(queue);
    posthog._i.push([apiKey, options || {}, instanceName]);

    var script = document.createElement("script");
    script.type = "text/javascript";
    script.async = true;
    script.src =
      (options.api_host || "https://eu.i.posthog.com").replace(/\/$/, "") +
      "/static/array.js";
    var firstScript = document.getElementsByTagName("script")[0];
    firstScript.parentNode.insertBefore(script, firstScript);
  };
  posthog.__SV = 1.2;
})(document, window);
