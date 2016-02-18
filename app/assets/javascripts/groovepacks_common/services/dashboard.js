groovepacks_services.factory('dashboard', ['$http', 'notification', 'auth', function ($http, notification, auth) {
  var get_default = function () {
    return {
      packing_stats: [],
      packed_item_stats: [],
      packing_speed_stats: [],
      avg_packing_speed_stats: [],
      avg_packing_accuracy_stats: [],
      main_summary: {},
      max_time_per_item: 0,
      packing_time_summary: {},
      packing_speed_summary: {}
    };
  };

  var get_max_time = function(dashboard) {
    return(
      $http.get('/settings/get_settings').success(function(response){
        if (response.status==true) {
          dashboard.max_time_per_item = response.data.settings.max_time_per_item;
        }
      })
    );
  };

  var update_max_time = function(max_time_per_item) {
    return(
      $http.put('/settings/update_settings?max_time_per_item=' + max_time_per_item).error(function(){
        notification.notify("Failed to update maximum expected time/item", 0);
      })
    );
  }

  var exceptions = function (user_id, type) {
    return (
      $http.get('/dashboard/exceptions?user_id=' + user_id + '&exception_type=' + type).error(function (response) {
        notification.notify("Failed to load exception statistics", 0);
      })
    );
  }

  var get_dashboard_data = function() {
    var tenant = document.getElementById('current_tenant').value;
    var domain = document.getElementById('domain').value;
    var site_host = document.getElementById('site_host').value;
    var access_token = localStorage.getItem('access_token');
    var created_at = localStorage.getItem('created_at');
    d = new Date();
    if (created_at > parseInt(d.getTime() / 1000) - 5400) {
      refresh_access_token().then(function(response){
        access_token = response;
        request_analytic_server(tenant, domain, site_host, access_token);
      });
    } else {
      request_analytic_server(tenant, domain, site_host, access_token);
    }
  };

  var refresh_access_token = function() {
    var refresh_token = localStorage.getItem('refresh_token');
    var url = document.URL.split('/');
    var target_url = url[0] + '//' + url[2] + '/auth/v1/getToken';
    return $http.get(target_url, {headers: {
      "Content-type": "application/x-www-form-urlencoded; charset=UTF-8",
      "Authorization": refresh_token
    }}).then(function (response) {
      if(response.status == 200){
        access_token = response.data.access_token;
        refresh_token = response.data.refresh_token;
        created_at = response.data.created_at;
      } else {
        access_token = null;
        refresh_token = null;
        created_at = null
      }
      localStorage.removeItem('access_token');
      localStorage.setItem('access_token', access_token);
      localStorage.removeItem('refresh_token');
      localStorage.setItem('refresh_token', refresh_token);
      localStorage.removeItem('created_at');
      localStorage.setItem('created_at', created_at);
      return access_token;
    });
  };

  var request_analytic_server = function(tenant, domain, site_host, access_token) {
    $http.get(
      // 'http://' + domain +'/dashboard/calculate',
      'http://' + tenant + 'stat.' + domain +'/dashboard/calculate',
      {headers: {'Authorization':'Bearer ' + access_token, 'domain':site_host, 'tenant':tenant}}
      ).error(function(response){
      notification.notify("Failed to load dashboard data", 0);
    });
  };

  return {
    model: {
      get: get_default,
      get_max: get_max_time,
      update_max: update_max_time
    },
    stats: {
      exceptions: exceptions,
      dashboard_stat: get_dashboard_data
    }
  };
}]);
