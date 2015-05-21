groovepacks_admin_controllers.
    controller('ordersModal', [ '$scope', '$state', '$modal', '$modalInstance', '$timeout','$q', 'orders', 'order_data','status',
        function(scope,$state,$modal, $modalInstance,$timeout,$q,orders,order_data,status) {

            var myscope = {};

            scope.ok = function() {
                $modalInstance.close("ok-button-click");
            };
            scope.cancel = function () {
                $modalInstance.dismiss("cancel-button-click");
            };
            scope.change_order_status_yes = function() {
                order_data.setup.status = status;
                orders.list.update_with_option('yes',order_data).then(function(data) {
                    scope.ok();
                });
            };
            scope.change_order_status_no = function() {
                order_data.setup.status = status;
                orders.list.update_with_option('no',order_data).then(function(data) {
                    scope.ok();
                });
            };
            scope.cancel_change_order_status = function() {
                scope.ok();
            };
        }
]);
