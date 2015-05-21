groovepacks_controllers.controller('scanPackRfpProductInstructions', [ '$scope', '$modalInstance', '$timeout', 'order_data','confirm', 'scanPack',
function($scope,$modalInstance,$timeout,order_data,confirm,scanPack){
    var myscope = {};

    myscope.init = function() {
        $scope.order = order_data;
        $timeout($scope.focus_search,200);
        $scope.code = {};
        $scope.code.confirmation = '';
    };

    $scope.check_product_confirm = function (event) {
        if(event.which != 13) return;
        $scope.update('ok-enter-key');
    };

    $scope.update = function(reason) {
        if(reason =='ok-enter-key') {
            scanPack.product_instruction($scope.order.id,$scope.order.next_item, $scope.code.confirmation).then(function(data) {
                $scope.code.confirmation = "";
                $timeout($scope.focus_search,200);
                if(data.data.status) {
                    $modalInstance.close("finished");
                    confirm();
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

    myscope.init();
}]);
