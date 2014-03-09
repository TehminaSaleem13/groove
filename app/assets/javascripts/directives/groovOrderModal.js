groovepacks_directives.directive('groovOrderModal',['notification','orders','products','$timeout','$http', function (notification, orders,products,$timeout,$http) {
    return {
        restrict:"A",
        templateUrl:"/assets/partials/ordermodal.html",
        scope: {
            order_single_details: "=groovSingleOrder",
            orders: "=groovOrders"
        },
        link: function(scope,el,attrs) {
            var myscope = {};
            scope.custom_identifier = Math.floor(Math.random()*1000);
            /**
             * Public properties
             */

            scope.item_products = products.model.get();
            scope.item_products.setup.is_kit = -1;
            scope.$watch('orders.single.items',function() {
                if(typeof scope.orders.single.basicinfo != "undefined") {
                    scope.item_products.list = [];
                    for(i in scope.orders.single.items) {
                        scope.item_products.list.push({id:scope.orders.single.items[i].iteminfo.product_id});
                    }
                }
            });


            /**
             * private properties
             */
            scope._keydown_last = false;
            scope._order_obj = null;

            /**
             * Public methods
             */
            $http.get('/home/userinfo.json').success(function(data){
                scope.username = data.username;
                scope.current_userid = data.user_id;
            });
            scope.order_single_details = function(id,index,post_fn, open_modal) {
                if(typeof open_modal == 'boolean' && open_modal ){
                    if(scope._order_obj == null) {
                        scope._order_obj = $("#showOrder"+scope.custom_identifier);
                        scope._order_obj.on('hidden',function(){
                            scope.update_single_order(false);
                            scope.$emit("orders-modal-closed",{identifier: scope.custom_identifier});
                        });
                    }
                    scope._order_obj.modal('show');

                }
                if(typeof index == 'number'){
                    scope.orders.current = index;
                } else {
                    for(i in scope.orders.list) {
                        if(scope.orders.list[i].id == id) {
                            scope.orders.current = parseInt(i);
                            break;
                        }
                    }
                }
                orders.single.get(id,scope.orders).then(function(data) {
                    var user_found = false;
                    var currentuser_idx = -1;


                    // for (i=0; i < scope.orders.single.users.length; i++) {
                    //     if (scope.orders.single.users[i].id == scope.current_userid) {
                    //         scope.orders.single.users[i].name = scope.orders.single.users[i].name + ' (Packing User)';
                    //         currentuser_idx = i;
                    //         break;
                    //     }
                    // }

                    for (i=0; i < scope.orders.single.users.length; i++) {
                        if (scope.orders.single.exception != null &&
                            scope.orders.single.exception.assoc != null &&
                            scope.orders.single.users[i].id == scope.orders.single.exception.assoc.id) {
                            scope.orders.single.exception.assoc = scope.orders.single.users[i];
                            user_found = true;
                            break;
                        }
                    }
                    if(typeof open_modal == 'boolean' && open_modal ){
                        myscope.single = {}
                        angular.copy(scope.orders.single,myscope.single);
                    }
                    if(typeof post_fn == 'function' ) {
                        $timeout(post_fn,10);
                    }
                });
            };

            scope.rollback = function() {
                angular.copy(myscope.single,scope.orders.single);
                orders.single.rollback(myscope.single).then(function(response){
                    scope.order_single_details(scope.orders.single.basicinfo.id);
                })

            }
            scope.update_single_order = function(auto) {
                orders.single.update(scope.orders,auto).then(function(response) {
                    scope.order_single_details(scope.orders.single.basicinfo.id);
                });
            }

            scope.add_item_order = function(event, args) {
                event.stopPropagation();
                orders.single.item.add(scope.orders,args.selected).then(function(response){
                    scope.order_single_details(scope.orders.single.basicinfo.id,false,function(){
                        scope._order_obj.modal("refresh");
                    });
                });
            }

            scope.item_remove_selected = function() {
                ids=[];
                for (i in scope.orders.single.items) {
                    if(scope.orders.single.items[i].checked ==true) {
                        ids.push(scope.orders.single.items[i].iteminfo.id);
                    }
                }
                orders.single.item.remove(ids).then(function(){
                    scope.order_single_details(scope.orders.single.basicinfo.id);
                });
            }

            scope.update_order_exception = function() {
                orders.single.exception.record(scope.orders).then(function(){
                    scope.order_single_details(scope.orders.single.basicinfo.id);
                });
            }

            scope.clear_order_exception = function() {
                orders.single.exception.clear(scope.orders).then(function(){
                    scope.order_single_details(scope.orders.single.basicinfo.id);
                });
            }

            scope.save_item = function(model,prop) {
                if(prop == 'qty') {
                    orders.single.item.update(model).then(function(response) {
                        scope.order_single_details(scope.orders.single.basicinfo.id);
                    });
                } else {
                    obj = {
                        id: (prop == 'name' || prop == 'is_skippable')? model.id : model.iteminfo.product_id,
                        var: (prop == 'qty_on_hand')? 'qty': ((prop == 'location')? 'location_name': prop),
                        value: model[prop]
                    }
                    products.list.update_node(obj).then(function(response) {
                        scope.order_single_details(scope.orders.single.basicinfo.id);
                    });
                }
            }

            scope.handle_keydown = function(event) {
                    if(event.which == 38) {//up key
                        if(scope.orders.current > 0) {
                            scope.order_single_details(scope.orders.list[scope.orders.current -1].id, scope.orders.current - 1,0,true);
                        } else {
                            alert("Already at the top of the list");
                        }
                    } else if(event.which == 40) { //down key

                        if(scope.orders.current < scope.orders.list.length -1) {
                            scope.order_single_details(scope.orders.list[scope.orders.current + 1].id, scope.orders.current + 1,0,true);
                        } else {
                            scope._keydown_last = true;
                            scope.$emit("orders-next-load");
                        }
                    } else if(event.which == 39 || event.which == 37){
                        //Horizontal movement
                        var mytab = $("#myTab"+scope.custom_identifier+" li");
                        var count = mytab.length;
                        var active_index = $("#myTab"+scope.custom_identifier+" li.active").index();
                        var next_index = 1;
                        var prev_index = count;

                        if(event.which == 39) { //right key
                            if(active_index+1 < count) {
                                next_index = active_index+2;
                            }
                            $("#myTab"+scope.custom_identifier+" li:nth-child("+next_index+") a").click();
                        } else if(event.which == 37) { //left key

                            if(active_index > 0) {
                                prev_index = active_index;
                            }
                            $("#myTab"+scope.custom_identifier+" li:nth-child("+prev_index+") a").click();
                        }
                    }

            }

            scope.itemEditableOptions = {
                update: scope.save_item,
                elements: {
                    qty: {type:'number',min:0},
                    qty_on_hand: {type:'number',min:0}
                },
                functions: {
                    name: function(id,index,post_fn,open_modal) {
                        scope.product_single_details(id,index,post_fn,open_modal);
                    }
                }
            };


            scope.$on("orders-next-loaded",function(){
                if(scope._keydown_last) {
                    scope._keydown_last = false;
                    if(scope.orders.current < scope.orders.list.length -1) {
                        scope.order_single_details(scope.orders.list[scope.orders.current + 1].id, scope.orders.current + 1,0, true);
                    } else {
                        alert("Already at the bottom of the list");
                    }
                }
            });
            scope.$on("orders-next-load", function() {
                $timeout(function() {
                    scope.$emit("orders-next-loaded");
                },5000);
            });
            scope.$on("products-next-load",function(event, args){event.stopPropagation(); scope.$broadcast("products-next-loaded");});
            scope.$on("alias-modal-selected",scope.add_item_order);
            scope.$on("products-modal-closed",function(event, args){ event.stopPropagation(); scope.order_single_details(scope.orders.single.basicinfo.id,scope.orders.current);});
            $('.icon-question-sign').popover({trigger: 'hover focus'});
            scope.$emit("order-modal-loading-complete",{identifier:scope.custom_identifier});
            scope.$on("product-modal-loading-complete",function(event, args){ event.stopPropagation(); });
        }
    };
}]);
