groovepacks_admin_controllers.controller('scanPackRfpTypeScan', [ '$scope', '$modalInstance', '$timeout', 'order_data','confirm', 'scanPack','notification',
function($scope, $modalInstance, $timeout, order_data, confirm, scanPack, notification){
    var myscope = {};

    myscope.init = function() {
        $scope.order = order_data;
        $timeout(function(){$scope.focus_search().select();},200);
        $scope.code = {};
        $scope.code.count = 0;
    };

    $scope.check_confirm = function (event) {
        if(event.which != 13) return;
        $scope.update('ok-enter-key');
    };

    $scope.update = function(reason) {
        if(reason =='ok-enter-key') {
            if ($scope.code.count != $scope.order.next_item.qty) {
                notification.notify("Wrong count has been entered. Please try again.");
                $modalInstance.dismiss("wrong-count");
            } else {
                scanPack.type_scan($scope.order.id,$scope.order.next_item, $scope.code.count).success(function(data) {
                    $scope.code.count = 0;
                    $timeout($scope.focus_search,200);
                    if(data.status) {
                        $modalInstance.close("finished");
                        confirm(data.data);
                    }
                });
            }

        }
    };

    $scope.ok = function() {
        $modalInstance.close("ok-button-click");
    };
    $scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
    };

    myscope.init();
}]);
