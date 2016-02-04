groovepacks_services.factory('dashboard', ['$http', 'notification', 'auth', function ($http, notification, auth) {
  var get_default = function () {
    return {
      packing_stats: [],
      packed_item_stats: [],
      packing_speed_stats: [],
      avg_packing_speed_stats: [],
      avg_packing_accuracy_stats: [],
      main_summary: {}
    };
  };

  var exceptions = function (user_id, type) {
    return (
      $http.get('/dashboard/exceptions?user_id=' + user_id + '&exception_type=' + type).error(function (response) {
        notification.notify("Failed to load exception statistics", 0);
      })
    );
  }

  var get_dashboard_data = function() {
    tenant = document.getElementById('current_tenant').value
    domain = document.getElementById('domain').value
    site_host = document.getElementById('site_host').value
    access_token = localStorage.getItem('access_token');
    return (
      $http.get(
        // 'http://' + domain +'/dashboard/calculate',
        'http://' + tenant + 'stat.' + domain +'/dashboard/calculate',
        {headers: {'tenant': tenant, 'access_token': access_token, 'domain': site_host}}
        ).error(function(response){
        notification.notify("Failed to load dashboard data", 0);
      })
    )
  }

  return {
    model: {
      get: get_default
    },
    stats: {
      exceptions: exceptions,
      dashboard_stat: get_dashboard_data
    }
  };
}]);
