groovepacks_controllers.
    controller('scanPackRfpDefaultCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','orders','scanPack',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, orders, scanPack) {
            var myscope = {};

            $scope.reset_order = function () {
                scanPack.reset($scope.data.order.id);
            }

            $scope.add_note = function() {
                if(myscope.note_obj == null) {
                    myscope.note_obj = $('#showNotesFromPacker');
                    myscope.note_obj.on('shown',function(){
                        $timeout(function(){
                            $('#note_from_packer').focus();
                        })
                    }).on('hidden',function() {
                        orders.list.update_node({id:$scope.data.order.id,var:"notes_from_packer",value:$scope.data.order.notes_fromPacker});
                        $('input.span12').focus();
                    })
                }
                myscope.note_obj.modal('show');
            }

            $scope.check_order_confirm = function (event) {
                if(event.which != 13) return;
                scanPack.order_instruction($scope.data.order.id,$scope.confirmation_code).then(function(data) {
                    $scope.confirmation_code = "";
                    if(data.data.status) {
                        myscope.order_instruction_confirmed = true;
                        myscope.order_instruction_obj.modal('hide');
                    }
                })
            }

            $scope.check_product_confirm = function (event) {
                if(event.which != 13) return;
                scanPack.product_instruction($scope.data.order.id,$scope.data.order.next_item,$scope.confirmation_code).then(function(data) {
                    $scope.confirmation_code = "";
                    if(data.data.status) {
                        myscope.product_instruction_confirmed_id = $scope.data.order.next_item.product_id;
                        myscope.product_instruction_obj.modal('hide');
                    }
                })
            }

            myscope.show_order_instructions = function () {
                if(myscope.order_instruction_obj  == null) {
                    myscope.order_instruction_obj  = $('#showOrderInstructions');
                    myscope.order_instruction_obj.on('shown',myscope.context_focus).on('hidden',myscope.context_focus);
                }
                myscope.order_instruction_obj.modal('show');
            }

            myscope.show_product_instructions = function () {
                if(myscope.product_instruction_obj  == null) {
                    myscope.product_instruction_obj  = $('#showProductInstructions');
                    myscope.product_instruction_obj.on('shown',myscope.context_focus).on('hidden',myscope.context_focus);
                }
                myscope.product_instruction_obj.modal('show');
            }

            myscope.context_focus = function() {
                if($('#showProductInstructions').hasClass('in')) {
                    myscope.do_focus($('#product_instruction'));
                } else if($('#showOrderInstructions').hasClass('in')) {
                    myscope.do_focus($('#order_instruction'));
                } else {
                    myscope.do_focus($('input.span12'));
                }
            }

            myscope.do_focus = function (el) {
                $timeout(function(){el.focus();},200);
            }

            myscope.compute_counts = function() {

                if(!myscope.order_instruction_confirmed && $scope.data.order.notes_toPacker) {
                    $timeout(myscope.show_order_instructions);
                }

                if(myscope.product_instruction_confirmed_id != $scope.data.order.next_item.product_id && $scope.data.order.next_item.confirmation ) {
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
