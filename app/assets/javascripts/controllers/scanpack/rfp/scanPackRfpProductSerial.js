groovepacks_controllers.controller('scanPackRfpProductSerial', [ '$scope', '$modalInstance', '$timeout', 'order_data','serial_data','confirm', 'scanPack',
function($scope,$modalInstance,$timeout,order_data,serial_data,confirm,scanPack) {
    var myscope = {};

    myscope.init = function() {
        $scope.order = order_data;
        $scope.code = serial_data;
        $timeout($scope.focus_search,200);
        $scope.code.serial = '';
    };

    $scope.check_product_serial = function (event) {
        if(event.which != 13) return;
        $modalInstance.close('ok-enter-key');
    };

    $scope.update = function(reason) {
        if(reason != 'cancel-button-click') {
            scanPack.product_serial($scope.code).then(function(data) {
                $scope.code.serial = '';
                $timeout($scope.focus_search,200);
                if(data.data.status) {
                    confirm(data.data);
                }
            });
        }
    };

    $scope.ok = function() {
        $modalInstance.close("ok-button-click");
    };
    $scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
    };
    $modalInstance.result.then($scope.update,$scope.update);

    myscope.init();
}]);
