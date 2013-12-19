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
            request_for_confirmation_code_with_order_edit: $scope._order_edit_confirmation_code_state,
            request_for_confirmation_code_with_product_edit: $scope._product_edit_confirmation_code_state,
            product_edit: $scope._product_edit_state,
            order_clicked: $scope._order_clicked_state,
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
        $("#showProductConfirmation").on('shown',function() {
            $scope._focus_input($scope._product_confirmation_inputObj);
        });
        $("#showOrderConfirmation").on('shown',function() {
            $scope._focus_input($scope._order_confirmation_inputObj);
        });
        $("#showProduct").on('hidden',$scope._refresh_inactive_list);
        $(".scan_product_times").disableSelection();
        $scope._next_state({next_state:"default"});
        $scope.set_products_defaults();
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
        $scope.order_details.items_to_scan = 0;
        $scope.order_details.total_items = 0;
        var next_item_set = false;
        for(i in $scope.order_details.items) {
            $scope.order_details.total_items += $scope.order_details.items[i].qty;
            $scope.order_details.items_to_scan -= $scope.order_details.items[i].scanned;
            if(!next_item_set && ($scope.order_details.items[i].scanned < $scope.order_details.items[i].qty)) {
                next_item_set = true;
                if($scope.next_item.id != $scope.order_details.items[i].id) {
                    $scope.item_image_index = 0;
                    $scope.next_item = $scope.order_details.items[i];
                }

            }
        }
        $scope.order_details.items_to_scan += $scope.order_details.total_items;
    }

    $scope._ready_for_order_state = function (data) {
        $scope.order_details = {};
        $scope.scanned_details = {};
        $scope.order_id = 0;
        $scope.next_item = {};
        $scope.inactive_new_products = [];
        $scope._set_rf_state('ready_for_order');
        $scope.hide_alert(-1);
        $scope._focus_input($scope._rf_inputObj);
    }

    $scope._order_clicked_state = function(data) {
        $(".modal").modal("hide");
        $scope.rf_input = data.barcode;
        $scope._handle_ready_for_order_enter_event();
    }

    $scope._ready_for_product_state = function (data) {
        $scope._set_rf_state('ready_for_product');
        $scope.rf_input = "";
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
                    if(data.order.items[i].productinfo.packing_placement == null) {
                        data.order.items[i].productinfo.packing_placement = 50;
                    }

                    neworderdetails.items.push( {
                        id: data.order.items[i].productinfo.id,
                        name: data.order.items[i].iteminfo.name,
                        packing_placement: data.order.items[i].productinfo.packing_placement,
                        images: data.order.items[i].productimages,
                        qty: data.order.items[i].iteminfo.qty,
                        scanned: data.order.items[i].iteminfo.scanned_qty,
                        instructions: data.order.items[i].productinfo.spl_instructions_4_packer,
                        confirmation: data.order.items[i].productinfo.spl_instructions_4_confirmation,
                        sku: data.order.items[i].iteminfo.sku,
                        time_adj: data.order.items[i].productinfo.pack_time_adj
                    });
                }

                //Sort here to have exact next item as needed
                neworderdetails.items.sort(function(a,b) {return ((a.packing_placement*100 - a.qty) > (b.packing_placement*100 - b.qty));});
                $scope.order_details = neworderdetails;
                $scope._next_item();
                $scope.scanned_details = $scope.order_details;
                //console.log($scope.order_details);
            } else {
                $scope.show_alert([data.error_message],0);
            }

        }).error(function(){
            $scope.show_alert(["Cannot load Order with id "+ $scope.order_id+". There was a server error"],0);
        });
    }

    $scope._order_edit_confirmation_code_state =  function(data) {
        $("#showOrderConfirmation").modal('show');
    }

    $scope._product_edit_confirmation_code_state = function(data) {
        $("#showProductConfirmation").modal('show');
    }

    $scope._product_edit_state = function(data) {
        $scope.inactive_new_products = data.inactive_or_new_products;
        $("#showProductList").modal('show');
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

    $scope._handle_order_confirmation_code_key_event = function(event) {
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
                        $scope.order_confirmation_code = "";
                        $scope._focus_input($scope._order_confirmation_inputObj);
                    }
               } else {
                   $scope.show_error_msgs = true;
                   $scope.error_msgs = data.error_messages;
                   $scope.order_confirmation_code = "";
                   $scope._focus_input($scope._order_confirmation_inputObj);
               }

           }).error(function() {
               $scope.show_alert(["There was a server error"],0);
           });
        }
    }

    $scope._refresh_inactive_list = function () {
        $http.post('/scan_pack/inactive_or_new.json',{order_id:$scope.order_id}).success(function(data){
            if(data.status) {
                $scope.hide_alert(-1);
                $scope.show_error_msgs = false;
                $scope._next_state(data.data);
            } else {
                $scope.show_error_msgs = true;
                $scope.error_msgs = data.error_messages;
            }

        }).error(function(){
            $scope.show_alert(["There was a server error"],0);
        });
    }

    $scope._handle_product_confirmation_code_key_event = function(event) {
        if(event.which == 13) {
            //console.log($scope.product_confirmation_code);
            $http.post('/scan_pack/product_edit_confirmation_code.json',{order_id:$scope.order_id,confirmation_code:$scope.product_confirmation_code}).success(function(data){
                //console.log(data);
                if(data.status){
                    if(data.data.product_edit_matched) {
                        $scope.hide_alert(-1);
                        $scope.show_error_msgs = false;
                        var stuff =  data.data;
                        $("#showProductConfirmation").modal('hide');
                            $scope._next_state(stuff);
                    } else {
                        $scope.show_error_msgs = true;
                        $scope.error_msgs = ["I’m sorry, the code you have scanned does not belong to a user who can scan orders that are On Hold.",
                            "Please get assistance from someone with this permission, or press escape to scan another order"];
                        $scope.product_confirmation_code = "";
                        $scope._focus_input($scope._product_confirmation_inputObj);

                    }
                } else {
                    $scope.show_error_msgs = true;
                    $scope.error_msgs = data.error_messages;
                    $scope.product_confirmation_code = "";
                    $scope._focus_input($scope._product_confirmation_inputObj);
                }
            }).error(function(){
                    $scope.show_alert(["There was a server error"],0);
            });
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
        $http.post('/scan_pack/scan_product_by_barcode.json',{barcode:$scope.rf_input,order_id:$scope.order_id}).success(function(data){

            //console.log(data);
            $scope.hide_alert(-1);
            if(data.status) {
                if(data.notice_messages.length) {
                    $scope.show_alert(data.notice_messages,2);
                }
                if(data.success_messages.length) {
                    $scope.show_alert(data.success_messages,1);
                }
            } else {
                $scope.show_alert(data.error_messages,0);
            }
            if(data.data != null) {
                $scope.rf_input = "";
                $scope._next_state(data.data);
            }

        }).error(function(data){
                $scope.show_alert(["A server error was encountered"],0);
            });

    }





    /** products methods **/
    $scope.edit_warehouse_node = function(index,id,name) {

        $scope.save_warehouse_node();
        $scope.warehouse_edit_tmp.editing_var = name;
        $scope.warehouse_edit_tmp.editing = index;
        $scope.warehouse_edit_tmp.editing_id = id;
        $scope.warehouse_edit_tmp[name] = $scope.single_product.inventory_warehouses[index][name];
        $scope.single_product.inventory_warehouses[index][name] = "";
        $timeout(function(){$scope.focus_input('warehouse_'+name+"_"+index);},20);
    }
    $scope.$on("fileSelected", function (event, args) {
        $("input[type='file']").val('');
        if(args.name =='product_image') {
            $scope.$apply(function () {
                $http({
                    method: 'POST',
                    headers: { 'Content-Type': false },
                    url:'/products/addimage.json',
                    transformRequest: function (data) {
                        var request = new FormData();
                        for (var key in data) {
                            request.append(key,data[key]);
                        }
                        return request;
                    },
                    data: {product_id: $scope.single_product.basicinfo.id, product_image: args.file}
                }).success(function(data) {
                        if(data.status) {
                            $scope.product_update_status = true;
                            $scope.product_update_message = "Successfully Updated";
                            $scope.product_single_details($scope.single_product.basicinfo.id);
                        } else {
                            $scope.show_error_msgs = true;
                            $scope.error_msgs = ["Some error Occurred"];
                        }

                    }).error(function() {
                        $scope.show_error_msgs = true;
                        $scope.error_msgs = ["Some error Occurred"];
                    });
            });
        }
    });
    $scope.save_warehouse_node = function() {
        if($scope.warehouse_edit_tmp.editing != -1 ) {
            $scope.single_product.inventory_warehouses[$scope.warehouse_edit_tmp.editing][$scope.warehouse_edit_tmp.editing_var] = $scope.warehouse_edit_tmp[$scope.warehouse_edit_tmp.editing_var];
            $scope.update_single_product();
            //$scope.single_product.inventory_warehouses[$scope.warehouse_edit_tmp.editing].checked = !$scope.single_product.inventory_warehouses[$scope.warehouse_edit_tmp.editing].checked;
        }
        $scope.warehouse_edit_tmp.editing_var = "";
        $scope.warehouse_edit_tmp.editing = -1;
        $scope.warehouse_edit_tmp.editing_id = -1;

    }
    $scope.add_warehouse = function() {
        var new_warehouse = {
            alert: "",
            location: "",
            name:"",
            qty: 0,
            location_primary:"",
            location_secondary:""
        }
        $scope.single_product.inventory_warehouses.push(new_warehouse);
        $scope.update_single_product(
            function() {
                $scope.product_single_details($scope.single_product.basicinfo.id,$scope.currently_open,
                    function() {
                        var warehouses = $scope.single_product.inventory_warehouses;
                        var last_warehouse = warehouses.length-1;
                        $scope.edit_warehouse_node(last_warehouse,$scope.single_product.inventory_warehouses[last_warehouse].id,'name');
                    });
            }
        );
    }
    $scope.remove_warehouses = function() {
        for(i in $scope.single_product.inventory_warehouses) {
            if($scope.single_product.inventory_warehouses[i].checked) {
                $scope.single_product.inventory_warehouses.splice(i,1);
            }
        }
        $scope.update_single_product();
    }
    $scope.select_deselect_warehouse = function(warehouse) {
        if($scope.warehouse_edit_tmp.editing == -1 ) {
            warehouse.checked = !warehouse.checked
        }
    }
    $scope.set_products_defaults = function () {
        $scope.product_update_status = false;
        $scope.product_update_message = "";
        $scope.do_get_products = false;
        $scope.can_get_products = true;
        $scope.product_setup = {};
        $scope.new_products = false;
        $scope.currently_open = 0;
        $scope.products = [];
        $scope.temp = {};
        $scope.temp.products = [];
        $scope.temp.product_setup = {};
    }
    $scope.product_single_details = function(id,index,post_fn) {
        $scope.loading = true;
        if(typeof index !== 'undefined'){
            $scope.currently_open = index;
        }
        $scope.warehouse_edit_tmp = {
            alert: "",
            location: "",
            name:"",
            qty: 0,
            location_primary:"",
            location_secondary:"",
            editing:-1,
            editing_var: "",
            editing_id:""
        };
        //console.log($scope.currently_open);
        $scope.single_product = {};
        $scope.selected_skus = [];
        $scope.tmp = {
            sku: "",
            barcode: "",
            category: "",
            editing: -1
        };
        $scope.tmp_options = {
            sku: 'skus',
            barcode: 'barcodes',
            category:'cats',
            image:'images'
        };
        $http.get('/products/getdetails/'+ id+'.json').success(function(data) {
            if(data.product) {
                $scope.single_product = data.product;
                $('#showProduct').modal('show');
            }
            //console.log($scope.single_product);
            if(typeof post_fn == 'function' ) {
                $timeout(post_fn,10);
            }
            $scope.loading = false;
        }).error(function(data) {
                if(typeof post_fn == 'function' ) {
                    $timeout(post_fn,20);
                }
                $scope.loading = false;
            });
    }

    $scope.update_single_product = function(post_fn) {
        $http.post('/products/updateproduct.json', $scope.single_product).success(function(data) {
            if(data.status) {
                $scope.product_update_status = true;
                $scope.show_error_msgs = false;
                $scope.product_update_message = "Successfully Updated";

            } else {
                $scope.show_error_msgs = true;
                $scope.error_msgs = ["Some error Occurred"];
            }
            if(typeof post_fn == 'function' ) {
                $timeout(post_fn,20);
            }
        }).error(function() {
                $scope.show_error_msgs = true;
                $scope.error_msgs = ["Some error Occurred"];
                if(typeof post_fn == 'function' ) {
                    $timeout(post_fn,20);
                }
            });
    }
    $scope.save_node = function(name,blur) {
        prop = $scope.tmp_options[name];
        if($scope.tmp[name] != "") {
            if($scope.tmp.editing == -1) {
                mytemp = {};
                mytemp[name] = $scope.tmp[name];
                $scope.single_product[prop].push(mytemp);
            } else {
                $scope.single_product[prop][$scope.tmp.editing][name] = $scope.tmp[name];
            }
            //$scope.update_single_product();
        }
        $scope.tmp[name] = "";
        $scope.tmp.editing = -1;
        $scope.tmp.editing_var = -1;
        $("#"+name+"-input").prepend($(".input-text input[name='"+name+"']"));
        if(!blur) {
            $scope.focus_input(name);
        }

    }

    $scope.remove_node = function(name,index) {
        prop = $scope.tmp_options[name];
        $scope.single_product[prop].splice(index,1);
        if(name !=="image") {
            $("#"+name+"-input").prepend($(".input-text input[name='"+name+"']"));
            $scope.focus_input(name);
            $scope.tmp.editing = -1;
            $scope.tmp.editing_var = -1;
        }
        $scope.update_single_product();
    }

    $scope.edit_node = function(name,index) {
        prop = $scope.tmp_options[name];
        if(index == -1) {
            index = $scope.single_product[prop].length-1;
        }
        $scope.save_node(name);
        $scope.tmp.editing = index;
        $scope.tmp.editing_var = name;
        $("#"+name+"-"+index).prepend($(".input-text input[name='"+name+"']"));
        $scope.focus_input(name);
        $scope.tmp[name] =  $scope.single_product[prop][index][name];
        $scope.single_product[prop][index][name] = "";
    }

    $scope.focus_input = function(name){
        $(".input-text [name='"+name+"']").focus();
    }
    $scope.blur_input = function(name) {
        $("#name").removeClass("input-text-hover");
        $("#"+name+"-input").addClass("false-tag-bubble");
        $scope.tmp[name] = "";
    }
    $scope.add_image = function (){
        $("#product_image").click();
    }

    $scope.handle_key_event =  function(event) {
        name = event.currentTarget.name;
        if(event.which == 13 || event.which == 188 || event.type == "focusout") {
            event.preventDefault();
            if($scope.tmp[name] != "") {
                $scope.save_node(name,event.type == "focusout");
            }
        }
        if(event.which == 8) {
            if($scope.tmp[name] == "") {
                index = $scope.tmp.editing;
                if(index != -1) {
                    $scope.remove_node(name,index);
                    index = index - 1;
                }
                $scope.edit_node(name,index);
            }
        }
    }


    $scope.keyboard_nav_event = function(event) {
        if($('#showProduct').hasClass("in")) {
            if(event.which == 38) {//up key
                if($scope.currently_open > 0) {
                    $scope.product_single_details($scope.inactive_new_products[$scope.currently_open -1].id, $scope.currently_open - 1);
                } else {
                    alert("Already at the top of the list");
                }
            } else if(event.which == 40) { //down key
                if($scope.currently_open < $scope.inactive_new_products.length -1) {
                    $scope.product_single_details($scope.inactive_new_products[$scope.currently_open + 1].id, $scope.currently_open + 1);
                } else {
                    alert("Already at the bottom of the list");
                }
            }

        }
    }


    $scope.$watch('can_get_products',function() {
        if($scope.can_get_products) {
            if($scope.do_get_products) {
                $scope.do_get_products = false;
                $scope.get_products();
            }
        }
    });
    $scope.$watch('product_update_status',function() {
        if($scope.product_update_status) {
            $("#product_update_status").fadeTo("fast",1,function() {
                $("#product_update_status").fadeTo("slow", 0 ,function() {
                    $scope.product_update_status = false;
                });
            });
        }
    });

    $('#showProduct').keydown($scope.keyboard_nav_event);
    $('.icon-question-sign').popover({trigger: 'hover focus'});
    input_text_selector = $('.input-text input');
    input_text_selector.keydown($scope.handle_key_event);
    input_text_selector.focusout(
        function(event) {
            $scope.handle_key_event(event);
            if(event.currentTarget.parentElement.id.slice(-6) == "-input") {
                $("#"+event.currentTarget.parentElement.parentElement.id).removeClass("input-text-hover");
                $("#"+event.currentTarget.parentElement.id).addClass("false-tag-bubble");
            }
            $scope.update_single_product();
        }
    );
    $('.regular-input').focusout($scope.update_single_product);
    input_text_selector.focus(
        function(event) {
            if(event.currentTarget.parentElement.id.slice(-6) == "-input") {
                $("#"+event.currentTarget.parentElement.parentElement.id).addClass("input-text-hover");
                $("#"+event.currentTarget.parentElement.id).removeClass("false-tag-bubble");
            } else {
                $("#"+event.currentTarget.parentElement.parentElement.parentElement.id).addClass("input-text-hover");
            }
        }
    );
    //Definitions end above this line
    /*
     * Initialization
     */
    $scope._init();
}]);
