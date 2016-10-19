groovepacks_controllers.controller('DashboardCtrl', function ($scope, $modal, $log, $http) {
  $scope.ok = function(avg, data_point){
    url = "/dashboard/update_to_avg_datapoint.json?avg=" + avg + "&&val=" + data_point;
    $http.post(url);
    $scope.modal_d.close();
  };
  $scope.cancel = function(){
    $scope.modal_d.close();
  };
});
