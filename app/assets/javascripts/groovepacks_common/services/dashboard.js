groovepacks_services.factory('dashboard', ['$http', 'notification', function ($http, notification) {
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


  var packing_stats = function (duration) {
    return (
      $http.get('/dashboard/packing_stats?duration=' + duration).error(function (response) {
        notification.notify("Failed to load packing statistics", 0);
      })
    );
  }

  var packing_speed_stats = function (duration) {
    return (
      $http.get('/dashboard/packing_speed?duration=' + duration).error(function (response) {
        notification.notify("Failed to load packing speed statistics", 0);
      })
    );
  }

  var packed_item_stats = function (duration) {
    return (
      $http.get('/dashboard/packed_item_stats?duration=' + duration).error(function (response) {
        notification.notify("Failed to load packed item statistics", 0);
      })
    );
  }

  var main_summary = function (duration) {
    return (
      $http.get('/dashboard/main_summary?duration=' + duration).error(function (response) {
        notification.notify("Failed to load main summary statistics", 0);
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

  var leader_board = function () {
    return (
      $http.get('/dashboard/leader_board').error(function (response) {
        notification.notify("Failed to load leader board", 0);
      })
    );
  }

  // var get_dashboard_data = function() {
  //   console.log('get_dashboard_data');
  //   return (
  //     $http.post('http://dhhq_stat.locallytics.com:4000/dashboard/calculate').error(function(response){
  //       notification.notify("Failed to load dashboard data", 0);
  //     })
  //   )
  // }

  return {
    model: {
      get: get_default
    },
    stats: {
      packing_stats: packing_stats,
      packed_item_stats: packed_item_stats,
      packing_speed_stats: packing_speed_stats,
      main_summary: main_summary,
      exceptions: exceptions,
      leader_board: leader_board
    }
  };
}]);
