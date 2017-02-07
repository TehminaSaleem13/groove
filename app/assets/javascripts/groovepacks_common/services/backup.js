groovepacks_services.factory('backup', ['$http', 'notification', function ($http, notification) {
  var get_default = function () {
    return {
      data: {
        method: 'del_import',
        file: null
      },
      settings: {
        single: {}
      }
    };
  };

  var restore_backup = function (backup_data) {
    return $http({
      method: 'POST',
      headers: {'Content-Type': undefined},
      url: '/settings/restore.json',
      transformRequest: function (data) {
        var request = new FormData();
        for (var key in data) {
          if (data.hasOwnProperty(key)) {
            request.append(key, data[key]);
            notification.notify("Request for Product restore has been queued. You will be notified via email once restore is complete.", 1);
          }
        }
        return request;
      },
      data: backup_data
    }).success(function (data) {
      if (data.status) {
        // notification.notify("Imported Successfully", 1);
      } else {
        notification.notify(data.messages);
      }
    }).error(notification.server_error);
  };

  var export_csv = function() {
    console.log('backup export_csv');
    return $http.get('/settings/export_csv.json').success(function(data) {
      if (data.status) {
        notification.notify("Backup queued", 1);
      } else{
        notification.notify(data.messages, 0);
      };
    })
  };

  return {
    model: {
      get: get_default
    },
    restore: restore_backup,
    back_up: export_csv
  };
}]);
