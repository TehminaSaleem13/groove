groovepacks_controllers.
    controller('scanPackRfpDefaultCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$modal','products', 'orders', 'scanPack','notification',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, $modal, products, orders, scanPack,notification) {
            var myscope = {};

            $scope.reset_order = function () {
                scanPack.reset($scope.data.order.id);
            };

            $scope.add_note = function() {
                myscope.note_obj = $modal.open({
                    templateUrl: '/assets/views/modals/scanpack/addnote.html',
                    controller: 'scanPackRfpAddNote',
                    size:'lg',
                    resolve: {order_data: function() {return $scope.data.order;}}
                });
                myscope.note_obj.result.finally(function() {
                    $timeout($scope.focus_search,500);
                });
            };

            $scope.autoscan_barcode = function() {
                if($scope.scan_pack.settings.enable_click_sku) {
                    if($scope.data.order.next_item.click_scan_enabled =="on_with_confirmation") {
                        myscope.show_click_scan_confirm();
                    } else if($scope.data.order.next_item.click_scan_enabled =="on") {
                        myscope.do_autoscan();
                    } else if($scope.data.order.next_item.click_scan_enabled =="off") {
                        notification.notify('Click Scan is disabled for this product');
                    }

                } else {
                    notification.notify('Click Scan is disabled');
                }
            };

            myscope.type_scan = function() {
                if($scope.scan_pack.settings.type_scan_code_enabled) {
                    var barcode_found = false;
                    if($scope.data.order.next_item.barcodes.length) {
                        for (var i=0; i< $scope.data.order.next_item.barcodes.length; i++) {
                            if($scope.get_last_scanned() == $scope.data.order.next_item.barcodes[i].barcode) {
                                barcode_found = true;
                            }
                        }
                    }
                    if (barcode_found) {
                        if($scope.data.order.next_item.type_scan_enabled =="on_with_confirmation") {
                            myscope.show_type_scan_confirm();
                        } else if($scope.data.order.next_item.type_scan_enabled =="on") {
                            myscope.launch_type_scan();
                        } else if($scope.data.order.next_item.type_scan_enabled =="off") {
                            notification.notify('Type-In Scan Count is disabled for this product');
                        }
                    } else {
                        notification.notify('To use Type-In Counts please scan the first item, then scan or enter: '+$scope.scan_pack.settings.type_scan_code+' You can then enter the quantity of the item.');
                    }
                } else {
                    notification.notify('Type-In Scan Count is disabled');
                }
                $scope.set('input','');
            };

            myscope.launch_type_scan = function() {
                myscope.type_scan_obj = $modal.open({
                    templateUrl: '/assets/views/modals/scanpack/typescan.html',
                    controller: 'scanPackRfpTypeScan',
                    size:'lg',
                    resolve: {
                        order_data: function() {return $scope.data.order;},
                        confirm:function(){ return $scope.handle_scan_return;}
                    }
                });
                myscope.type_scan_obj.result.finally(function() {
                    $scope.set('input','');
                    $timeout($scope.focus_search,500);
                });
            };

            myscope.do_autoscan = function(){
                scanPack.click_scan($scope.data.order.next_item.barcodes[0].barcode,$scope.data.order.id).success($scope.handle_scan_return);
            };


            $scope.product_details = function(id) {
                if($scope.current_user.can('add_edit_products')) {
                    var item_modal = $modal.open({
                        templateUrl: '/assets/views/modals/product/main.html',
                        controller: 'productsSingleModal',
                        size:'lg',
                        resolve: {
                            product_data: function(){return products.model.get()},
                            load_page: function(){return function() {
                                var req = $q.defer();
                                req.reject();
                                return req.promise;
                            }},
                            product_id: function(){return id;}
                        }
                    });
                    item_modal.result.finally(myscope.check_reload_compute);
                }
            };

            myscope.show_type_scan_confirm = function () {
                if(myscope.type_scan_confirmed_id != $scope.data.order.next_item.product_id) {
                    myscope.type_scan_confirm_obj = $modal.open({
                        templateUrl: '/assets/views/modals/scanpack/codeconfirm.html',
                        controller: 'scanPackRfpCodeConfirm',
                        size:'lg',
                        resolve: {
                            order_data: function() {return $scope.data.order;},
                            confirm:function(){return function(){myscope.type_scan_confirmed_id = $scope.data.order.next_item.product_id; myscope.launch_type_scan();}}
                        }
                    });
                    myscope.type_scan_confirm_obj.result.finally(function() {
                        $timeout($scope.focus_search,500);
                        $timeout(myscope.show_type_scan_confirm,100);
                    });
                } else {
                    myscope.type_scan_confirmed_id = 0;
                }
            };

            myscope.show_click_scan_confirm = function () {
                if(myscope.click_scan_confirmed_id != $scope.data.order.next_item.product_id) {
                    myscope.click_scan_confirm_obj = $modal.open({
                        templateUrl: '/assets/views/modals/scanpack/codeconfirm.html',
                        controller: 'scanPackRfpCodeConfirm',
                        size:'lg',
                        resolve: {
                            order_data: function() {return $scope.data.order;},
                            confirm:function(){return function(){myscope.click_scan_confirmed_id = $scope.data.order.next_item.product_id; myscope.do_autoscan();}}
                        }
                    });
                    myscope.click_scan_confirm_obj.result.finally(function() {
                        $timeout($scope.focus_search,500);
                        $timeout(myscope.show_click_scan_confirm,100);
                    });
                } else {
                    myscope.click_scan_confirmed_id = 0;
                }
            };

            myscope.show_order_instructions = function () {
                if(!myscope.order_instruction_confirmed) {
                    myscope.order_instruction_obj = $modal.open({
                        templateUrl: '/assets/views/modals/scanpack/orderinstructions.html',
                        controller: 'scanPackRfpOrderInstructions',
                        size:'lg',
                        resolve: {
                            order_data: function(){return $scope.data.order;},
                            scan_pack_settings: function(){return $scope.scan_pack.settings;},
                            confirm:function(){return function(){myscope.order_instruction_confirmed = true;}}
                        }
                    });
                    myscope.order_instruction_obj.result.finally(function() {
                        $timeout($scope.focus_search,500);
                        $timeout(myscope.show_order_instructions,100);
                    });
                }
            };

            myscope.show_product_instructions = function () {
                if(myscope.product_instruction_confirmed_id != $scope.data.order.next_item.product_id) {
                    myscope.product_instruction_obj = $modal.open({
                        templateUrl: '/assets/views/modals/scanpack/productinstructions.html',
                        controller: 'scanPackRfpProductInstructions',
                        size:'lg',
                        resolve: {
                            order_data: function() {return $scope.data.order;},
                            confirm:function(){return function(){myscope.product_instruction_confirmed_id = $scope.data.order.next_item.product_id;}}
                        }
                    });
                    myscope.product_instruction_obj.result.finally(function() {
                        $timeout($scope.focus_search,500);
                        $timeout(myscope.show_product_instructions,100);
                    });
                }
            };

            myscope.ask_serial = function(serial) {
                myscope.serial_obj = $modal.open({
                    templateUrl: '/assets/views/modals/scanpack/productserial.html',
                    controller: 'scanPackRfpProductSerial',
                    size:'lg',
                    resolve: {
                        order_data: function() {return $scope.data.order;},
                        serial_data:function(){return serial; },
                        confirm: function(){return $scope.handle_scan_return;}
                    }
                });
                myscope.serial_obj.result.finally(function() {
                    $timeout($scope.focus_search,500);
                });
            };

            myscope.compute_counts = function() {
                if(!myscope.order_instruction_confirmed && 
                    ($scope.general_settings.single.conf_req_on_notes_to_packer ==="always" || 
                        ($scope.general_settings.single.conf_req_on_notes_to_packer ==="optional" && 
                            $scope.data.order.note_confirmation)) && 
                    ($scope.data.order.notes_toPacker || $scope.data.order.notes_internal 
                        || $scope.data.order.customer_comments)) {
                    $timeout(myscope.show_order_instructions);
                }
                if(typeof $scope.data.order['next_item'] !== 'undefined' && ($scope.general_settings.single.conf_code_product_instruction ==="always" || ($scope.general_settings.single.conf_code_product_instruction ==="optional" && $scope.data.order.next_item.confirmation)) && myscope.product_instruction_confirmed_id !== $scope.data.order.next_item.product_id) {
                    $timeout(myscope.show_product_instructions);
                }

                $scope.unscanned_count = 0;
                $scope.scanned_count = 0;
                $scope.item_image_index = 0;

                for (var i = 0;  i < $scope.data.order.unscanned_items.length; i++) {
                    if ($scope.data.order.unscanned_items[i].product_type == 'single') {
                        $scope.unscanned_count = $scope.unscanned_count + $scope.data.order.unscanned_items[i].qty_remaining;
                    }
                    else if ($scope.data.order.unscanned_items[i].product_type == 'individual') {
                        for (var j=0; j< $scope.data.order.unscanned_items[i].child_items.length;  j++) {
                            $scope.unscanned_count += $scope.data.order.unscanned_items[i].child_items[j].qty_remaining;
                        }
                    }
                }

                for (var k = 0;  k < $scope.data.order.scanned_items.length; k++) {
                    if ($scope.data.order.scanned_items[k].product_type == 'single'){
                        $scope.scanned_count = $scope.scanned_count + $scope.data.order.scanned_items[k].scanned_qty;
                    }
                }

            };

            myscope.handle_known_codes = function(){
                if($scope.scan_pack.settings.note_from_packer_code_enabled && $scope.data.input == $scope.scan_pack.settings.note_from_packer_code) {
                    $scope.add_note();
                    myscope.note_obj.result.finally(function() {
                        $scope.set('input','');
                    });
                    return false;
                } else if($scope.scan_pack.settings.service_issue_code_enabled && $scope.data.input == $scope.scan_pack.settings.service_issue_code && !myscope.service_issue_message_saved) {
                    $scope.add_note();
                    notification.notify("Please add a message with the service issue",2);
                    myscope.note_obj.result.finally(function() {
                        $scope.set('input',$scope.scan_pack.settings.service_issue_code);
                        myscope.service_issue_message_saved = true;
                        $scope.input_enter({which:13});
                    });
                    return false;
                } else if($scope.scan_pack.settings.type_scan_code_enabled && $scope.data.input == $scope.scan_pack.settings.type_scan_code) {
                    myscope.type_scan();
                    return false;
                } else if($scope.scan_pack.settings.restart_code_enabled && $scope.data.input == $scope.scan_pack.settings.restart_code) {
                    $scope.reset_order();
                }
                return true;
            };

            myscope.check_reload_compute = function () {
                $scope.rfpinit().then(function () {
                    $scope.set('title', "Ready for Product Scan");
                    if(typeof $scope.data.raw.data.serial != 'undefined' && $scope.data.raw.data.serial.ask) {
                        myscope.ask_serial($scope.data.raw.data.serial);
                    }
                    if($scope.data.order.status != "awaiting") {
                        $scope.set('order',{});
                        $scope.rfpinit().then(myscope.compute_counts);
                    } else {
                        myscope.compute_counts();
                    }
                    $scope.reg_callback(myscope.handle_known_codes);
                });
            };

            myscope.init = function() {
                myscope.note_obj = null;
                myscope.serial_obj = null;
                myscope.order_instruction_confirmed = false;
                myscope.order_instruction_obj = null;
                myscope.product_instruction_obj = null;
                myscope.product_instruction_confirmed_id = 0;
                myscope.click_scan_confirm_obj = null;
                myscope.click_scan_confirmed_id =0;
                myscope.type_scan_confirm_obj = null;
                myscope.type_scan_confirmed_id =0;
                $scope.confirmation_code = "";
                myscope.service_issue_message_saved = false;
                myscope.check_reload_compute();
            };

            $scope.$on('reload-scanpack-state',myscope.check_reload_compute);
            myscope.init();
        }]);
