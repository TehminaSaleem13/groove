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
    try{
      var tenant = document.getElementById('current_tenant').value
    }
    catch(e){
      tenant=null;
    }
    
    if(tenant)
    {
      var domain = document.getElementById('domain').value;
      var site_host = document.getElementById('site_host').value;
      var access_token = localStorage.getItem('access_token');
      var created_at = localStorage.getItem('created_at');
      var url = document.URL.split('/');
      d = new Date();
      if (created_at > parseInt(d.getTime() / 1000) - 5400) {
        refresh_access_token(url).then(function(response){
          access_token = response;
          request_analytic_server(tenant, domain, site_host, access_token, url[0]);
        });
      } else {
        request_analytic_server(tenant, domain, site_host, access_token,url[0]);
      }
    }
  };

  var refresh_access_token = function(url) {
    var refresh_token = localStorage.getItem('refresh_token');
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

  var request_analytic_server = function(tenant, domain, site_host, access_token, protocol) {
    $http.get(
      // protocol + '//' + domain +'/dashboard/calculate',
      protocol + '//' + tenant + 'stat.' + domain +'/dashboard/calculate',
      {headers: {'Authorization':'Bearer ' + access_token, 'domain':site_host, 'tenant':tenant}}
      ).error(function(response){
      notification.notify("Failed to load dashboard data", 0);
    });
  };

  var get_datapoints_data = function(dashboard, charts, date, y) {
    data_points = {};
    data_points.data = [];
    data_points.user = [];
    dashboard_data = {};
    if (charts.type === 'packing_stats' || charts.type === 'packing_error') {
      dashboard_data = dashboard.packing_stats;
    } else if (charts.type === 'packing_speed_stats' || charts.type === 'packing_time_stats') {
      dashboard_data = dashboard.packing_speed_stats;
    } else if (charts.type === 'packed_item_stats' || charts.type === 'packed_order_stats') {
      dashboard_data = dashboard.packed_item_stats;
    }
    for (var i = dashboard_data.length - 1; i >= 0; i--) {
      for (var j = dashboard_data[i].values.length - 1; j >= 0; j--) {
        if (moment(dashboard_data[i].values[j][0] * 1000).format('L') == moment(date * 1000).format('L') &&
          dashboard_data[i].values[j][1] == y) {
          data_points.data.push(dashboard_data[i].values[j]);
          data_points.user.push([dashboard_data[i].key, dashboard_data[i].color]);
        };
      };
    };
    return data_points;
  }

  var get_tool_tip = function(data_points, charts, dashboard) {
    var tooltipText = '';
    for (var i = data_points.data.length - 1, j=0; i >= 0; i--, j++) {
        date = d3.time.format('%b %e, %Y')(moment.unix(data_points.data[i][0]).toDate());
        col_sm = Math.floor(12/data_points.data.length);
        col_sm = col_sm < 3 ? 3 : col_sm
        if(j % 4 == 0){ tooltipText += (j == 0 ? '<div class="col-sm-12"> <div class="row">' : '</div></div><hr><div class="col-sm-12"><div class="row">') }
        tooltipText += '<div class="col-sm-' + col_sm + ' col-md-' + col_sm + ' col-lg-' + col_sm + '"><h4 style="text-transform: capitalize; color:' + data_points.user[i][1] +
        '">' + data_points.user[i][0] + '</h4>';
      if (charts.type === 'packing_stats' || charts.type === 'packing_error') {
        tooltipText += 
        '<span><strong>' + date + '</strong></span><br/>' +
        '<span><strong>Period Accuracy: ' + data_points.data[i][5] + '% </strong></span><br/>' +
        '<span><strong>Day\'s Accuracy: ' + data_points.data[i][1] + '% </strong></span><br/>' +
        '<span><strong>' + data_points.data[i][2] + ' Orders Scanned</strong></span><br/>' +
        '<span><strong>' + data_points.data[i][3] + ' Items Packed </strong></span><br/>' +
        '<span><strong>' + data_points.data[i][4] + ' Exceptions Recorded</strong></span>';

        if (data_points.data[i][6] != null && data_points.data[i][7] != null) {
          var orders = data_points.data[i][6].split(' ')
          var dates = data_points.data[i][7].split(' ')
          tooltipText += '<legend style="border-bottom: 2px solid rgba(0,0,1,.86); margin-bottom: 10px;"></legend>';
          for (var j = 0; j < orders.length - 1; j++) {
            if (dates[j] == '') {
              tooltipText +=
              '<span><span style="margin-bottom: -4px; text-transform: capitalize; color:' + data_points.user[i][1] +
              '"><strong>#' + orders[j] + '</strong></span><br/>' +
              '<span style="margin-top: -4px;"><strong>Recorded: </strong></span></span><br/>';
            } else{
              tooltipText +=
              '<span><span style="margin-bottom: -4px; text-transform: capitalize; color:' + data_points.user[i][1] +
              '"><strong>#' + orders[j] + '</strong></span><br/>' +
              '<span style="margin-top: -4px;"><strong>Recorded: ' + d3.time.format('%b %e, %Y')(moment.unix(dates[j]).toDate()) + '</strong></span></span><br/>';
            };
            
          };
        }
        tooltipText += '</div>';
      } else if (charts.type === 'packing_speed_stats' || charts.type === 'packing_time_stats') {
        tooltipText +=
        '<span><strong>Period Speed Score: </strong>' + get_speed(data_points.data[i][2], dashboard) + '% </span><br/>' +
        '<span><strong>Date: </strong>' + date + '</span><br/>' +
        '<span><strong>Daily Speed Score: </strong>' + get_speed(data_points.data[i][1], dashboard) + '% </span><br/>' +
        '<span><strong>Avg. Time/Item: </strong>' + data_points.data[i][1] + ' sec</span>' +
        '<legend style="border-bottom: 2px solid rgba(0,0,1,.86); margin-bottom: 10px;"></legend>' +
        '</div>';
      } else if (charts.type === 'packed_item_stats' || charts.type === 'packed_order_stats') {
        single_tooltip = data_points.data[i][1] + ' items packed <br/>' + data_points.data[i][2] + ' orders';
        tooltipText +=
          '<span><strong>' + date + '</strong></span><br/>' +
          '<span><strong>' + single_tooltip + '<strong></span>' +
          '<legend style="border-bottom: 2px solid rgba(0,0,1,.86); margin-bottom: 10px;"></legend>' +
          '</div>';
      }
    }
    return tooltipText;
  }

  var get_speed = function(avg, dashboard) {
    if (avg === 0) {
      return 0;
    };
    var speed = dashboard.max_time_per_item - avg;
    if (speed < 0) {
      return (100 + speed).toFixed(2);
    } else {
      return 100;
    }
  };

  return {
    model: {
      get: get_default,
      get_max: get_max_time,
      update_max: update_max_time
    },
    stats: {
      exceptions: exceptions,
      dashboard_stat: get_dashboard_data,
      points_data: get_datapoints_data,
      tooltip: get_tool_tip,
      speed: get_speed
    }
  };
}]);
