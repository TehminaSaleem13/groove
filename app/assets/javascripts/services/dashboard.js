groovepacks_services.factory('dashboard',['$http','notification',function($http, notification) {
  var get_default = function() {
    return [];
  };



  var packing_stats = function(duration, packing_stats) {
    return(
      $http.get('/dashboard/packing_stats?duration='+ duration).success(function(response) {
        console.log(response)
        packing_stats = response;
      }).error(function(event){
        notification.notify("Failed to load packing statistics",0);
      })
    );
  }

  return {
    model: {
        get:get_default
    },
    stats: {
      packing_stats: packing_stats
    }
  };
}]);