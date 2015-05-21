groovepacks_admin_controllers.controller('exportOrderExceptionCtrl', [ '$state','$scope','$window',function($state,$scope,$window) {
    var myscope = {};
    myscope.defaults = function() {
        return {
            start: {
                open:false,
                time: new Date()
            },
            end: {
                open:false,
                time: new Date()
            }
        }
    };

    myscope.init = function() {
        $scope.exception = myscope.defaults();
        $scope.serial = myscope.defaults();
        $scope.setup_page('backup_restore',$state.current.url.substring(1));
    };

    $scope.open_picker = function(event,object) {
        event.preventDefault();
        event.stopPropagation();
        object.open =true;
    };

    $scope.download_csv = function(which) {
        if(['exception','serial'].indexOf(which) != -1) {
            if($scope[which].start.time <= $scope[which].end.time) {
                $window.open('/settings/order_'+which+'s.csv?start='+$scope[which].start.time+'&end='+$scope[which].end.time);
            } else {
                $scope.notify('Start time can not be after End time');
            }
        } else {
            $scope.notify('Unknown csv requested');
        }

    };
    myscope.init();
}]);
