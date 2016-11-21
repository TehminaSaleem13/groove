groovepacks_controllers.controller('DashboardCtrl', ['$scope', '$modal', '$log', '$http', 'dashboard', function ($scope, $modal, $log, $http, dashboard) {
  $scope.ok = function(){
    url = "/dashboard/update_to_avg_datapoint.json?avg=" + dashboard_data.avg + "&val=" + dashboard_data.data_point + "&username=" + dashboard_data.username ;
    $http.post(url);
    dashboard_data.modal_d.close();
  };
  $scope.cancel = function(){
    dashboard_data.modal_d.close();
  };
}]);
