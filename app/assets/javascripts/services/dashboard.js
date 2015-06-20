groovepacks_services.factory('dashboard',['$http','notification',function($http, notification) {
  var get_default = function() {
    return {
      packing_stats: [],
      packed_item_stats: []
    };
  };



  var packing_stats = function(duration) {
    return(
      $http.get('/dashboard/packing_stats?duration='+ duration).error(function(response){
        notification.notify("Failed to load packing statistics",0);
      })
    );
  }

  var packed_item_stats = function(duration) {
    return(
      $http.get('/dashboard/packed_item_stats?duration='+ duration).error(function(response){
        notification.notify("Failed to load packed item statistics",0);
      })
    );
  }

  return {
    model: {
        get:get_default
    },
    stats: {
      packing_stats: packing_stats,
      packed_item_stats: packed_item_stats
    }
  };
}]);