groovepacks_controllers.
    controller('scanPackRfpDefaultCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$modal', 'orders', 'scanPack',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, $modal, orders, scanPack) {
            var myscope = {};

            $scope.reset_order = function () {
                scanPack.reset($scope.data.order.id);
            }
            myscope.resolve = function() {
                return $scope.data.order;
            }
            $scope.add_note = function() {
                myscope.note_obj = $modal.open({
                    templateUrl: '/assets/views/modals/scanpack/addnote.html',
                    controller: 'scanPackRfpAddNote',
                    size:'lg',
                    resolve: {order_data: myscope.resolve}
                });
                myscope.note_obj.result.finally(function(reason) {
                    $('.col-xs-12 input.search-box').focus();
                });

            }

            myscope.show_order_instructions = function () {
                myscope.order_instruction_obj = $modal.open({
                    templateUrl: '/assets/views/modals/scanpack/orderinstructions.html',
                    controller: 'scanPackRfpOrderInstructions',
                    size:'lg',
                    resolve: {order_data: myscope.resolve}
                });
                myscope.order_instruction_obj.result.finally(function(reason) {
                    if(reason=="finished") {
                        myscope.order_instruction_confirmed = true;
                    }
                    $('.col-xs-12 input.search-box').focus();
                });
            }

            myscope.show_product_instructions = function () {
                myscope.product_instruction_obj = $modal.open({
                    templateUrl: '/assets/views/modals/scanpack/productinstructions.html',
                    controller: 'scanPackRfpProductInstructions',
                    size:'lg',
                    resolve: {order_data: myscope.resolve}
                });
                myscope.product_instruction_obj.result.finally(function(reason) {
                    if(reason=="finished") {
                        myscope.product_instruction_confirmed_id = $scope.data.order.next_item.product_id;
                    }
                    $('.col-xs-12 input.search-box').focus();
                });
            }

            myscope.compute_counts = function() {

                if(!myscope.order_instruction_confirmed && $scope.data.order.notes_toPacker) {
                    $timeout(myscope.show_order_instructions);
                }

                if(typeof $scope.data.order['next_item'] !== 'undefined' && myscope.product_instruction_confirmed_id != $scope.data.order.next_item.product_id && $scope.data.order.next_item.confirmation ) {
                    $timeout(myscope.show_product_instructions);
                }

                $scope.unscanned_count = 0;
                $scope.scanned_count = 0;
                $scope.item_image_index = 0;

                for (i = 0;  i < $scope.data.order.unscanned_items.length; i++) {
                    if ($scope.data.order.unscanned_items[i].product_type == 'single') {
                        $scope.unscanned_count = $scope.unscanned_count + $scope.data.order.unscanned_items[i].qty_remaining;
                    }
                    else if ($scope.data.order.unscanned_items[i].product_type == 'individual') {
                        for (j=0; j< $scope.data.order.unscanned_items[i].child_items.length;  j++) {
                            $scope.unscanned_count += $scope.data.order.unscanned_items[i].child_items[j].qty_remaining;
                        }
                    }
                }

                for (i = 0;  i < $scope.data.order.scanned_items.length; i++) {
                    if ($scope.data.order.scanned_items[i].product_type == 'single'){
                        $scope.scanned_count = $scope.scanned_count + $scope.data.order.scanned_items[i].scanned_qty;
                    }
                }

            }

            myscope.check_reload_compute = function () {
                $scope.rfpinit().then(function () {
                    $scope.set('title', "Ready for Product Scan");
                    if($scope.data.order.status != "awaiting") {
                        $scope.set('order',{});
                        $scope.rfpinit().then(myscope.compute_counts);
                    } else {
                        myscope.compute_counts();
                    }
                });
            }

            myscope.init = function() {
                myscope.note_obj = null;
                myscope.order_instruction_confirmed = false;
                myscope.order_instruction_obj = null;
                myscope.product_instruction_obj = null;
                myscope.product_instruction_confirmed_id = 0;
                $scope.confirmation_code = "";
                myscope.check_reload_compute();
            }

            $scope.$on('reload-scanpack-state',myscope.check_reload_compute);
            myscope.init();
        }]);
