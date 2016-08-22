groovepacks_services.factory('generalsettings', ['$http', 'notification', function ($http, notification) {


  //default object
  var get_default = function () {
    return {
      single: {}
    };
  };

  var get_settings = function (settings) {
    time_in_zone = moment().format("Z");
    var url = '/settings/get_settings.json';
    return $http.get(url).success(
      function (data) {
        if (data.status) {
          settings.single = data.data.settings;
          settings.single.time_zones = data.time_zone
          settings.single.current_time = data.current_time
          settings.single.time_to_send_email = new Date(data.data.settings.time_to_send_email);
          if(data.user_sign_in_count<2 && data.data.settings.time_zone == null) {
            time_zone = {}
            time_zone["add_time_zone"] = time_in_zone;
            time_zone["auto_detect"] = "true";
            add_time_zone(time_zone);
          }
        } else {
          notification.notify(data.error_messages, 0);
        }
      }
    ).error(notification.server_error);
  };

  var fix_times = function (settings) {
    var today = null;
    var all = ['time_to_import_orders', 'time_to_send_email'];
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

  var update_settings = function (settings) {
    var url = '/settings/update_settings.json';
    fix_times(settings);
    return $http.put(url, settings.single).success(
      function (data) {
        if (data.status) {
          get_settings(settings);
          notification.notify(data.success_messages, 1);
        } else {
          notification.notify(data.error_messages, 0);
        }
      }
    ).error(notification.server_error);
  };

  var add_time_zone = function (time_zone, settings) {
    var url = '/settings/fetch_and_update_time_zone.json';
    return $http.post(url, time_zone).success(function (data) {
      settings.single.current_time = data.current_time
    });
  }

  //Public facing API
  return {
    model: {
      get: get_default
    },
    single: {
      update: update_settings,
      get: get_settings,
      add_time_zone: add_time_zone
    }
  };

}]);
