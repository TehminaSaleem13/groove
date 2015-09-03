groovepacks_admin_services.factory('settings', ['$http', 'notification', function ($http, notification) {


  var save_column_preference = function (identifier, theads) {
    return $http.post('/settings/save_columns_state.json', {
      identifier: identifier,
      theads: theads
    }).success(function (data) {
      if (data.status) {
        notification.notify("Successfully saved column preferences", 1);
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var get_column_preference = function (identifier) {
    return $http.get('settings/get_columns_state.json?identifier=' + identifier).success(function (data) {
      if (!data.status) {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var cancel_bulk_action = function (id) {
    return $http.post('/settings/cancel_bulk_action.json', {id: id}).success(function (data) {
      notification.notify(data['error_messages']);
      notification.notify(data['success_messages'], 1);
      notification.notify(data['notice_messages'], 2);
    }).error(notification.server_error);
  };


  //Public facing API
  return {
    column_preferences: {
      get: get_column_preference,
      save: save_column_preference
    },
    cancel_bulk_action: cancel_bulk_action
  };


}]);
