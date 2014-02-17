groovepacks_directives.directive('groovOrderModal',['notification','orders','$timeout', function (notification, orders,$timeout) {
    return {
        restrict:"A",
        templateUrl:"/assets/partials/ordermodal.html",
        scope: {
            order_single_details: "=groovSingleOrder",
            orders: "=groovOrders"
        },
        link: function(scope,el,attrs) {
            scope.custom_identifier = Math.floor(Math.random()*1000);
            /**
             * Public properties
             */



            /**
             * private properties
             */
            scope._keydown_last = false;
            scope._order_obj = null;

            /**
             * Public methods
             */
            scope.order_single_details = function(id,index,post_fn, open_modal) {
                console.log("asdasdasd");
                if(typeof open_modal == 'boolean' && open_modal ){
                    if(scope._order_obj == null) {
                        scope._order_obj = $("#showOrder"+scope.custom_identifier);
                        scope._order_obj.on('hidden',function(){
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
                    console.log(scope.orders);
                    if(typeof post_fn == 'function' ) {
                        $timeout(post_fn,10);
                    }
                });
            };

            scope.update_single_order = function(auto) {
                if(typeof auto !="boolean") {
                    auto = false;
                }

                order_data = {};
                for(i in scope.orders.single.basicinfo) {
                    if(i != 'id' && i != 'created_at' && i!='updated_at') {
                        order_data[i] = scope.orders.single.basicinfo[i];
                    }
                }

                orders.single.update(scope.orders,auto).then(function(response) {
                    scope.order_single_details(scope.orders.basicinfo.id);
                });

            }
            scope.add_item_order = function(ids) {
                orders.single.item.add(scope.orders,ids).then(function(response){
                    scope.order_single_details(scope.orders.single.basicinfo.id);
                });
            }

            scope.item_remove_seleted = function() {
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

            scope.handle_keydown = function(event) {
                if($('#showOrder').hasClass("in") &&  !$('#addItem').hasClass("in")) {
                    if(event.which == 38) {//up key
                        if(scope.orders.currently_open > 0) {
                            scope.order_single_details(scope.orders.list[scope.orders.current -1].id, scope.orders.current - 1);
                        } else {
                            alert("Already at the top of the list");
                        }
                    } else if(event.which == 40) { //down key

                        if(scope.orders.current < scope.orders.length -1) {
                            scope.order_single_details(scope.orders.list[scope.orders.current + 1].id, scope.orders.current + 1);
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
            }




            scope.$on("orders-next-loaded",function(){
                if(scope._keydown_last) {
                    scope._keydown_last = false;
                    if(scope.orders.currently_open < scope.orders.list.length -1) {
                        scope.order_single_details(scope.orders.list[scope.currently_open + 1].id, scope.currently_open + 1,0, false);
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
            scope.$on("alias-modal-selected",scope._add_order_item);
            scope.$on("products-modal-closed",function(event, args){ event.stopPropagation(); scope.order_single_details(scope.orders.single.basicinfo.id,scope.currently_open);});
            $('.icon-question-sign').popover({trigger: 'hover focus'});
            scope.$emit("order-modal-loading-complete",{identifier:scope.custom_identifier});
            scope.$on("product-modal-loading-complete",function(event, args){ event.stopPropagation(); });
        }
    };
}]);
