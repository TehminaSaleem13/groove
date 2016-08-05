groovepacks_services.factory('exportsettings', ['$http', 'notification', function ($http, notification) {


  //default object
  var get_default = function () {
    return {
      single: {}
    };
  };

  var get_export_settings = function (settings) {
    var url = '/exportsettings/get_export_settings.json';

    return $http.get(url).success(
      function (data) {
        if (data.status) {
          settings.single = data.data.settings;
          settings.single.time_to_send_export_email = new Date(data.data.settings.time_to_send_export_email);
        } else {
          notification.notify(data.error_messages, 0);
        }
      }
    ).error(notification.server_error);
  };

  var fix_time = function (settings) {
    var today = null;
    var all = ['time_to_send_export_email'];
    var config_date = null;
    for (var i = 0; i < all.length; i++) {
      config_date = new Date(settings.single[all[i]]);
      today = new Date();
      today.setHours(config_date.getHours());
      today.setMinutes(config_date.getMinutes());
      today.setSeconds(0);
      settings.single[all[i]] = today;
    }

  };

  var update_export_settings = function (settings) {
    var url = '/exportsettings/update_export_settings.json';
    fix_time(settings);

    return $http.put(url, settings.single).success(
      function (data) {
        if (data.status) {
          get_export_settings(settings);
          notification.notify(data.success_messages, 1);
        } else {
          notification.notify(data.error_messages, 0);
        }
      }
    ).error(notification.server_error);
  };

  //Public facing API
  return {
    model: {
      get: get_default
    },
    single: {
      update: update_export_settings,
      get: get_export_settings
    }
  };

}]);
