groovepacks_controllers.controller('exportOrderExceptionCtrl', [ '$scope','$window',function($scope,$window) {
    var myscope = {};
    myscope.init = function() {
        $scope.start = {
            open:false,
            time: new Date()
        };
        $scope.end = {
            open:false,
            time: new Date()
        };
        $scope.setup_page('system','order_exception');
    };

    $scope.open_picker = function(event,object) {
        event.preventDefault();
        event.stopPropagation();
        object.open =true;
    };

    $scope.download_csv = function() {
        if($scope.start.time <= $scope.end.time) {
            $window.open('/settings/order_exceptions.csv?start='+$scope.start.time+'&end='+$scope.end.time);
        } else {
            $scope.notify('Start time can not be after End time');
        }
    };
    myscope.init();
}]);
