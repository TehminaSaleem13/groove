groovepacks_controllers.controller('scanPackRfpOrderInstructions', [ '$scope', '$modalInstance', '$timeout', 'order_data', 'scanPack',
function($scope,$modalInstance,$timeout,order_data,scanPack){
    $modalInstance.opened.finally(function(){
        $timeout(function(){
            $('#order_instruction').focus();
            $timeout(function(){
                $scope.order = order_data;
            });
        },100);
    });
    $scope.check_order_confirm = function (event) {
        if(event.which != 13) return;
        $scope.update('ok-enter-key');
    }

    $scope.update = function(reason) {
        if(reason != "cancel-button-click") {
            scanPack.order_instruction($scope.order.id,$scope.confirmation_code).then(function(data) {
                $scope.confirmation_code = "";
                if(data.data.status) {
                    $modalInstance.close("finished");
                }
            });
        }
    };
    $modalInstance.result.then($scope.update,$scope.update);

    $scope.ok = function() {
        $modalInstance.close("ok-button-click");
    };
    $scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
    }
}]);
