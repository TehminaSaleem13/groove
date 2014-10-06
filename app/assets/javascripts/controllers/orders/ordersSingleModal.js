groovepacks_controllers.
    controller('ordersSingleModal', [ '$scope', 'order_data', 'load_page', '$state', '$stateParams','$modal', '$modalInstance', '$timeout','$q', 'hotkeys', 'orders','products',
        function(scope,order_data,load_page,$state,$stateParams,$modal, $modalInstance,$timeout,$q,hotkeys,orders,products) {

            var myscope = {};

            /**
             * private properties
             */

            /**
             * Public methods
             */

            scope.ok = function() {
                $modalInstance.close("ok-button-click");
            };
            scope.cancel = function () {
                $modalInstance.dismiss("cancel-button-click");
            };

            scope.update = function(reason) {
                if(reason == "cancel-button-click") {
                    myscope.rollback();
                } else {
                    scope.update_single_order(false);
                }
            };

            myscope.order_single_details = function(id,new_rollback) {

                for(var i =0; i< scope.orders.list.length; i++) {
                    if(scope.orders.list[i].id == id) {
                        scope.orders.current = parseInt(i);
                        break;
                    }
                }
                orders.single.get(id,scope.orders).then(function(data) {
                    var user_found = false;
                    var currentuser_idx = -1;
                    for (i=0; i < scope.orders.single.users.length; i++) {
                        if (scope.orders.single.exception != null &&
                            scope.orders.single.exception.assoc != null &&
                            scope.orders.single.users[i].id == scope.orders.single.exception.assoc.id) {
                            scope.orders.single.exception.assoc = scope.orders.single.users[i];
                            user_found = true;
                            break;
                        }
                    }
                    if(typeof new_rollback == 'boolean' && new_rollback ){
                        myscope.single = {};
                        angular.copy(scope.orders.single,myscope.single);
                    }
                });
            };

            myscope.rollback = function() {
                scope.orders.single = {};
                angular.copy(myscope.single,scope.orders.single);
                return orders.single.rollback(myscope.single).then(function(response){
                    myscope.order_single_details(scope.orders.single.basicinfo.id);
                })

            };

            scope.update_single_order = function(auto) {
                scope.date_picker.show_button=false;
                orders.single.update(scope.orders,auto).then(function(response) {
                    myscope.order_single_details(scope.orders.single.basicinfo.id);
                });
            };

            scope.open_date_picker = function(event){
                event.stopPropagation();
                event.preventDefault();

                scope.date_picker.opened = true;
            };

            scope.add_item_order = function(args) {
                if(typeof args != 'undefined') {
                    orders.single.item.add(scope.orders,args.selected).then(function(response){
                        myscope.order_single_details(scope.orders.single.basicinfo.id);
                    });
                }
            };

            scope.item_remove_selected = function() {
                var ids=[];
                for (var i = 0; i< scope.orders.single.items.length; i++) {
                    if(scope.orders.single.items[i].checked ==true) {
                        ids.push(scope.orders.single.items[i].iteminfo.id);
                    }
                }
                orders.single.item.remove(ids).then(function(){
                    myscope.order_single_details(scope.orders.single.basicinfo.id);
                });
            };

            scope.update_order_exception = function() {
                orders.single.exception.record(scope.orders).then(function(){
                    myscope.order_single_details(scope.orders.single.basicinfo.id);
                });
            };

            scope.clear_order_exception = function() {
                orders.single.exception.clear(scope.orders).then(function(){
                    myscope.order_single_details(scope.orders.single.basicinfo.id);
                });
            };

            scope.save_item = function(model,prop) {
                if(prop == 'qty') {
                    orders.single.item.update(model).then(function(response) {
                        myscope.order_single_details(scope.orders.single.basicinfo.id);
                    });
                } else {
                    var obj = {
                        id: (prop == 'name' || prop == 'is_skippable' || prop == 'status')? model.id : model.iteminfo.product_id,
                        var: prop,
                        value: model[prop]
                    };
                    products.list.update_node(obj).then(function(response) {
                        myscope.order_single_details(scope.orders.single.basicinfo.id);
                    });
                }
            };
            myscope.up_key = function(event) {
                event.preventDefault();
                event.stopPropagation();
                if(scope.orders.current > 0) {
                    myscope.load_item(scope.orders.current -1);
                } else {
                    load_page('previous').then(function(){
                        myscope.load_item(scope.orders.list.length -1);
                    },function(){
                        alert("Already at the top of the list");
                    });
                }
            };
            myscope.down_key = function (event) {
                event.preventDefault();
                event.stopPropagation();
                if(scope.orders.current < scope.orders.list.length -1) {
                    myscope.load_item(scope.orders.current +1);
                } else {
                    load_page('next').then(function(){
                        myscope.load_item(0);
                    }, function(){
                        alert("Already at the bottom of the list");
                    });
                }
            };
            myscope.left_key = function (event) {
                event.preventDefault();
                event.stopPropagation();
                var tabs_len = scope.modal_tabs.length-1;
                for (var i = 0; i <= tabs_len; i++) {
                    if(scope.modal_tabs[i].active) {
                        //scope.modal_tabs[i].active = false;
                        scope.modal_tabs[((i==0)? tabs_len : (i-1))].active = true;
                        break;
                    }
                }
            };
            myscope.right_key = function (event) {
                event.preventDefault();
                event.stopPropagation();
                var tabs_len = scope.modal_tabs.length-1;
                for (var i = 0; i <= tabs_len; i++) {
                    if(scope.modal_tabs[i].active) {
                        //scope.modal_tabs[i].active = false;
                        scope.modal_tabs[((i==tabs_len)? 0 : (i+1))].active = true;
                        break;
                    }
                }
            };

            myscope.add_hotkeys = function() {
                hotkeys.del('up');
                hotkeys.del('down');
                hotkeys.del('left');
                hotkeys.del('right');
                hotkeys.del('esc');

                $timeout(function() {
                    hotkeys.bindTo(scope).add({
                        combo: 'up',
                        description: 'Previous order',
                        callback: myscope.up_key
                    }).add({
                        combo: 'down',
                        description: 'Next order',
                        callback: myscope.down_key
                    }).add({
                        combo: 'left',
                        description: 'Previous tab',
                        callback: myscope.left_key
                    }).add({
                        combo: 'right',
                        description: 'Next tab',
                        callback: myscope.right_key
                    }).add({
                        combo: 'esc',
                        description: 'Save and close modal',
                        callback: function(){}
                    });

                },2000);
            };

            myscope.handle_click_fn = function(row,event) {
                if(typeof event !='undefined') {
                    event.preventDefault();
                    event.stopPropagation();
                }
                var item_modal = $modal.open({
                    templateUrl: '/assets/views/modals/product/main.html',
                    controller: 'productsSingleModal',
                    size:'lg',
                    resolve: {
                        product_data: function(){return scope.item_products},
                        load_page: function(){return function() {
                            var req = $q.defer();
                            req.reject();
                            return req.promise;
                        };},
                        product_id: function(){return row.productinfo.id;}
                    }
                });
                item_modal.result.finally(function(){
                    myscope.order_single_details(scope.orders.single.basicinfo.id);
                    myscope.add_hotkeys();
                });
            };
            scope.item_order = function(type,exceptions,id) {
                var alias_modal = $modal.open({
                    templateUrl: '/assets/views/modals/product/alias.html',
                    controller: 'aliasModal',
                    size:'lg',
                    resolve: {
                        type: function(){return type},
                        exceptions: function(){return exceptions},
                        id: function(){return id;}
                    }
                });
                alias_modal.result.then(scope.add_item_order);
            };
            myscope.load_item = function(id) {
                var newStateParams = angular.copy($stateParams);
                newStateParams.order_id = ""+scope.orders.list[id].id;
                myscope.order_single_details(scope.orders.list[id].id, true);
                $state.go($state.current.name, newStateParams);
            };

            myscope.init = function() {
                scope.orders = order_data;
                //All tabs
                scope.modal_tabs = [
                    {
                        active:true,
                        heading:"Information",
                        templateUrl:'/assets/views/modals/order/information.html'
                    },
                    {
                        active:false,
                        heading:"Items",
                        templateUrl:'/assets/views/modals/order/items.html'
                    },
                    {
                        active:false,
                        heading:"Notes",
                        templateUrl:'/assets/views/modals/order/notes.html'
                    },
                    {
                        active:false,
                        heading:"Activities & Exceptions",
                        templateUrl:'/assets/views/modals/order/act_exception.html'
                    }
                ];
                $modalInstance.result.then(scope.update,scope.update);
                /**
                 * Public properties
                 */
                scope.date_picker = {};
                scope.date_picker.opened = false;
                scope.date_picker.format = 'dd-MMMM-yyyy';
                scope.date_picker.show_button =false;
                scope.item_products = products.model.get();
                scope.item_products.setup.is_kit = -1;
                scope.$watch('orders.single.items',function() {
                    if(typeof scope.orders.single.basicinfo != "undefined") {
                        scope.item_products.list = [];
                        for(var i = 0; i< scope.orders.single.items.length; i++) {
                            scope.item_products.list.push({id:scope.orders.single.items[i].iteminfo.product_id});
                        }
                    }
                });


                scope.gridOptions = {
                    identifier:'orderitems',
                    draggable:false,
                    show_hide:true,
                    selectable:true,
                    editable: {
                        update: scope.save_item,
                        elements: {
                            qty: {type:'number',min:0},
                            qty_on_hand: {type:'number',min:0},
                            is_skippable: {
                                type:'select',
                                options:[
                                    {name:"Yes",value:true},
                                    {name:"No",value:false}
                                ]
                            },
                            status: {
                                type:'select',
                                options:[
                                    {name:"Active",value:'active'},
                                    {name:"Inactive",value:'inactive'},
                                    {name:"New",value:'new'}
                                ]
                            }
                        },
                        functions: {
                            name: myscope.handle_click_fn
                        }
                    },
                    all_fields: {
                        name: {
                            name:"Product",
                            hideable: false,
                            model:"row.productinfo",
                            transclude: '<a href="" ng-click="options.editable.functions.name(row,event)" >{{row.productinfo.name}}</a>'
                        },
                        image: {
                            name:"Primary Image",
                            editable:false,
                            transclude:'<div class="single-image"><img class="img-responsive" ng-src="{{row.productimages[0].image}}" /></div>'
                        },
                        sku: {
                            name:"Primary SKU"
                        },
                        location_primary: {
                            name:"Primary location"
                        },
                        status: {
                            name:"Status",
                            model:"row.productinfo",
                            transclude: '<span>{{row.productinfo.status}}</span>'
                        },
                        qty: {
                            name:"Qty ordered",
                            model:"row.iteminfo",
                            transclude: '<span>{{row.iteminfo.qty}}</span>'
                        },
                        qty_on_hand: {
                            name:"On hand",
                            editable:false
                        },
                        is_skippable: {
                            name: "Is Skippable",
                            model:"row.productinfo",
                            transclude: '<span ng-show="row.productinfo.is_skippable">Yes</span> <span ng-hide="row.productinfo.is_skippable">No</span>'
                        }
                    }
                };
                myscope.add_hotkeys();
                myscope.order_single_details($stateParams.order_id,true);
            };
            myscope.init();
            //$('.icon-question-sign').popover({trigger: 'hover focus'});
        }

]);
