groovepacks_controllers.
controller('showScanPackCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
    //Definitions

    /*
     * Public methods
     */

    $scope.show_alert = function(msg,type) {
        $scope._set_alert(type,msg,true);
    }

    $scope.hide_alert = function(type) {
        if(type === -1) {
            for (i in $scope._alert_statuses) {
                $scope._set_alert(i);
            }
        } else {
            $scope._set_alert(type);
        }
    }






    /*
     * Private methods
     */
    //Constructor
    $scope._init = function() {
        // Public properties
        $scope.rf_input = "";
        $scope.order_confirmation_code = "";
        $scope.product_confirmation_code = "";
        $scope.next_item = {};
        $scope.next_item_index = 0;
        $scope.cur_order_bonus = 0;
        $scope.session_bonus = 0;
        $scope.scan_accuracy = 0;
        $scope.last_product_time = 0;


        //Private properties
        $scope._alert_statuses = {
            0: "error",
            1: "success",
            2: "notice",
            default: 0
        }
        $scope._rf_states = {
            ready_for_order: "Order",
            ready_for_product: "Product",
            default: "ready_for_order"
        }

        $scope._next_states = {
            ready_for_order: $scope._ready_for_order_state,
            ready_for_product: $scope._ready_for_product_state,
            request_for_confirmation_code_with_order_edit: $scope._order_edit_confirmation_code,
            request_for_confirmation_code_with_product_edit: $scope._product_edit_confirmation_code,
            default: "ready_for_order"

        }
        $scope._rf_inputObj = $('input#rf_input');
        $scope._order_confirmation_inputObj = $('input#order_edit_confirmation_code');
        $scope._product_confirmation_inputObj = $('input#product_edit_confirmation_code');

        //Register events and make function calls
        $http.get('/home/userinfo.json').success(function(data){
            $scope.username = data.username;
        });
        $scope._rf_inputObj.keydown($scope._handle_rf_key_event);
        $scope._order_confirmation_inputObj.keydown($scope._handle_order_confirmation_code_key_event);
        $scope._product_confirmation_inputObj.keydown($scope._handle_product_confirmation_code_key_event);
        $scope._next_state({next_state:"default"});
    }

    $scope._set_rf_state = function(state) {
        if(typeof state == "undefined" || typeof $scope._rf_states[state] == "undefined" || state == "default") {
            state = $scope._rf_states["default"];
        }
        $scope.rf_state_text = $scope._rf_states[state];
        $scope.rf_state = state;
    }

    $scope._next_state = function(data) {
        var state = data.next_state;
        if(typeof state == "undefined" || typeof $scope._next_states[state] == "undefined" || state == "default") {
            state = $scope._next_states["default"];
        }
        //console.log(data);
        $scope._next_states[state](data);
    }

    $scope._next_item = function() {
        if($scope.next_item.scanned < $scope.next_item.qty) {
            $scope.next_item.scanned++;
            $scope.order_details.items_to_scan--;
        } else {
            if($scope.next_item_index in $scope.order_details.items) {
                //
            }
        }
    }

    $scope._ready_for_order_state = function (data) {
        $scope.order_details = {};
        $scope.scanned_details = {};
        $scope.order_id = 0;
        $scope.next_item_index = 0;
        $scope.next_item = {};
        $scope._set_rf_state('ready_for_order');
        $scope.hide_alert(-1);
        $scope._focus_input($scope._rf_inputObj);
    }

    $scope._ready_for_product_state = function (data) {
        $scope._set_rf_state('ready_for_product');
        $scope._focus_input($scope._rf_inputObj);
        $http.get('/orders/getdetails.json?id='+$scope.order_id).success(function(data) {
            if(data.status) {
                //console.log(data);
                var neworderdetails =  {};
                neworderdetails.items_to_scan = 0;
                neworderdetails.total_items = 0;
                neworderdetails.items = [];
                neworderdetails.instructions = data.order.basicinfo.notes_toPacker;

                for( i in  data.order.items) {
                    neworderdetails.total_items +=  data.order.items[i].iteminfo.qty;
                    if(data.order.items[i].productinfo.packing_placement == null) {
                        data.order.items[i].productinfo.packing_placement = 50;
                    }

                    neworderdetails.items.push( {
                        name: data.order.items[i].iteminfo.name,
                        placement: parseInt((data.order.items[i].productinfo.packing_placement * 10100) - (data.order.items[i].iteminfo.qty * 100) + i),
                        packing_placement: data.order.items[i].productinfo.packing_placement,
                        images: data.order.items[i].productimages,
                        qty: data.order.items[i].iteminfo.qty,
                        scanned: 0,
                        instructions: data.order.items[i].productinfo.spl_instructions_4_packer,
                        confirmation: data.order.items[i].productinfo.spl_instructions_4_confirmation,
                        sku: data.order.items[i].iteminfo.sku,
                        time_adj: data.order.items[i].productinfo.pack_time_adj
                    });
                }
                neworderdetails.items_to_scan = neworderdetails.total_items;
                //Sort here to have exact next item as needed
                neworderdetails.items.sort(function(a,b) {return (a.placement > b.placement);});
                $scope.order_details = neworderdetails;
                $scope.next_item_index = 0;
                $scope.next_item = $scope.order_details.items[0];
                $scope.scanned_details = $scope.order_details;
                //console.log($scope.order_details);
            } else {
                $scope.show_alert([data.error_message],0);
            }

        }).error(function(){
            $scope.show_alert(["Cannot load Order with id "+ $scope.order_id+". There was a server error"],0);
        });
    }

    $scope._order_edit_confirmation_code =  function(data) {
        $("#showOrderConfirmation").modal('show').on('shown',function() {
            $scope._focus_input($scope._order_confirmation_inputObj);
        });
    }

    $scope._product_edit_confirmation_code = function(data) {
        $("#showProductConfirmation").modal('show').on('shown',function() {
            $scope._focus_input($scope._product_confirmation_inputObj);
        });
    }

    $scope._set_alert = function(type,msg,status) {
        if(typeof type != "number" ||  typeof $scope._alert_statuses[type] == "undefined") {
            type = $scope._alert_statuses["default"];
        }
        if(typeof status != "boolean") {
            status = false;
        }
        if(typeof msg == "undefined") {
            msg = [];
        }
        var alert = $scope._alert_statuses[type];

        $scope['show_'+alert] = status;
        $scope[alert + '_msg'] = msg;
    }

    $scope._focus_input = function(obj) {
        var object = obj;
        $timeout(function() {object.focus()},20);
    }
    $scope._handle_rf_key_event = function(event) {
        if(event.which == 13) {
            $scope['_handle_'+$scope.rf_state+'_enter_event']();
        }
    }

    $scope._handle_order_confirmation_code_key_event = function() {
        if(event.which == 13) {
           $http.post('/scan_pack/order_edit_confirmation_code.json',{order_id:$scope.order_id,confirmation_code:$scope.order_confirmation_code}).success(function(data){
               if(data.status) {
                   //console.log(data);
                    if(data.data.order_edit_matched) {
                        $scope.hide_alert(-1);
                        $scope.show_error_msgs = false;
                        $scope._next_state(data.data);
                        $("#showOrderConfirmation").modal('hide').on('hidden',function() {
                            $scope._focus_input($scope._rf_inputObj);
                        });

                    } else {
                        $scope.show_error_msgs = true;
                        $scope.error_msgs = ["I’m sorry, the code you have scanned does not belong to a user who can scan orders that are On Hold.",
                            "Please get assistance from someone with this permission, or press escape to scan another order"];
                    }
               } else {
                   $scope.show_error_msgs = true;
                   $scope.error_msgs = data.error_messages;
               }

           }).error(function() {
               $scope.show_alert(["Cannot load Order with id "+ $scope.order_id+". There was a server error"],0);
           });
        }
    }

    $scope._handle_product_confirmation_code_key_event = function() {
        if(event.which == 13) {
            //console.log($scope.product_confirmation_code);
            $scope.show_error_msgs = true;
            $scope.error_msgs = ["Product edit confirmation is yet to be implemented"];
        }
    }

    $scope._handle_ready_for_order_enter_event = function() {
        $http.get('/scan_pack/scan_order_by_barcode.json?barcode='+$scope.rf_input).success(function(data){
            //console.log(data);
            $scope.hide_alert(-1);
            if(data.status) {
                if(data.notice_messages.length) {
                    $scope.show_alert(data.notice_messages,2);
                }
                if(data.success_messages.length) {
                    $scope.show_alert(data.success_messages,1);
                }
                if(data.data != null) {
                    $scope.order_id = data.data.id;
                    $scope.rf_input = "";
                    $scope._next_state(data.data);
                }
            } else {
                $scope.show_alert(data.error_messages,0);
            }

        }).error(function(data){
                $scope.show_alert(["A server error was encountered"],0);
        });
    }

    $scope._handle_ready_for_product_enter_event = function() {
        //console.log("Product enter event occurred");
        $scope.show_alert(["Product Scanning is yet to be implemented"],0);
    }

    //Definitions end above this line
    /*
     * Initialization
     */
    $scope._init();
}]);
