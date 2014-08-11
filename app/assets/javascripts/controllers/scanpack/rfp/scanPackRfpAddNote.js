groovepacks_controllers.
    controller('scanPackRfpAddNote', [ '$scope', '$modalInstance', '$timeout', 'order_data', 'orders',
        function($scope,$modalInstance,$timeout,order_data,orders){
            $modalInstance.opened.finally(function(){
                $timeout(function(){
                    $('#note_from_packer').focus();
                    $timeout(function(){
                        $scope.order = order_data;
                    });
                },100);
            });
            $scope.update = function(reason) {
                if(reason != "cancel-button-click") {
                    orders.list.update_node({id:$scope.order.id,var:"notes_from_packer",value:$scope.order.notes_fromPacker});
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
