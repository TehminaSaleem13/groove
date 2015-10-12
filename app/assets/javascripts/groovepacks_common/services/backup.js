groovepacks_services.factory('backup', ['$http', 'notification', function ($http, notification) {
  var get_default = function () {
    return {
      data: {
        method: 'del_import_new',
        file: null
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
          }
        }
        return request;
      },
      data: backup_data
    }).success(function (data) {
      if (data.status) {
        notification.notify("Imported Successfully", 1);
      } else {
        notification.notify(data.messages);
      }
    }).error(notification.server_error);
  };

  return {
    model: {
      get: get_default
    },
    restore: restore_backup
  };
}]);
