groovepacks_controllers.
    controller('productsSingleModal', [ '$scope','auth', 'product_data', 'load_page', 'product_id', 'hotkeys', '$state', '$stateParams', '$modalInstance', '$timeout','$modal','$q','groov_translator','products','warehouses','generalsettings',
    function(scope,auth,product_data,load_page, product_id, hotkeys, $state,$stateParams,$modalInstance,$timeout,$modal,$q,groov_translator,products,warehouses,generalsettings) {
        var myscope = {};


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
            hotkeys.del('up');
            hotkeys.del('down');
            if(reason == "cancel-button-click") {
                myscope.rollback();
            } else {
                scope.update_single_product(false);
            }
        };

        myscope.product_single_details = function(id,new_rollback) {
            //console.log(index);
            //console.log(scope.products);

            for(var i = 0; i< scope.products.list.length; i++) {
                if(scope.products.list[i].id == id) {
                    scope.products.current = parseInt(i);
                    break;
                }
            }

            products.single.get(id,scope.products).success(function(data) {
                warehouses.list.get(scope.warehouses).success(function() {
                    for(var i =0; i < scope.products.single.inventory_warehouses.length;i++) {
                        for(var j =0; j<scope.warehouses.list.length;j++) {
                            if(scope.products.single.inventory_warehouses[i].warehouse_info.id == scope.warehouses.list[j].info.id) {
                                scope.warehouses.list.splice(j,1);
                                break;
                            }
                        }
                    }
                });

                if(typeof new_rollback == 'boolean' && new_rollback ){
                    myscope.single = {};
                    angular.copy(scope.products.single, myscope.single);
                }
            });
        };

        myscope.rollback = function() {
            if ($state.params.new_product) {
                products.list.update('delete',{selected: [{id:scope.products.single.basicinfo.id,checked:true}], setup:{ select_all: false, inverted: false, productArray:[]}}).then(function(){
                    if($state.current.name=='products.type.filter.page') {
                        $state.reload();
                    }
                });
            } else {
                scope.products.single = {};
                angular.copy(myscope.single,scope.products.single);
                scope.update_single_product(false);
            }
        };

        scope.load_kit = function(kit,event) {
            if(typeof event !='undefined') {
                event.preventDefault();
                event.stopPropagation();
            }
            var kit_modal = $modal.open({
                templateUrl: '/assets/views/modals/product/main.html',
                controller: 'productsSingleModal',
                size:'lg',
                resolve: {
                    product_data: function(){return scope.kit_products},
                    load_page: function(){return function() {
                        var req = $q.defer();
                        req.reject();
                        return req.promise;
                    };},
                    product_id: function(){return kit.option_product_id;}
                }
            });
            kit_modal.result.finally(function(){
                myscope.product_single_details(scope.products.single.basicinfo.id);
                myscope.add_hotkeys();
            });
        };

        scope.product_alias = function(type,exceptions,id) {
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
            alias_modal.result.then(function(data) {
                myscope.add_alias_product(type,data);
            });
        };
        scope.add_image = function () {
            $("#product_image"+scope.custom_identifier).click();
        };
        scope.remove_image = function(index) {
            scope.products.single.images.splice(index,1);
            scope.update_single_product();
        };
        scope.$on("fileSelected", function (event, args) {
            $("input[type='file']").val('');
            if(args.name =='product_image') {
                scope.$apply(function () {
                    products.single.image_upload(scope.products,args).then(function(response) {
                          myscope.product_single_details(scope.products.single.basicinfo.id);
                    });
                });
            }
        });

        myscope.add_alias_product = function(type,args) {
            if(typeof args !="undefined") {
                if(type == 'kit') {
                    products.single.kit.add(scope.products,args.selected).then(function(response) {
                        //console.log(response.data);
                        myscope.product_single_details(scope.products.single.basicinfo.id);
                    });
                } else if(type =='master_alias') {
                    products.single.master_alias(scope.products,args.selected).then(function() {
                        myscope.product_single_details(scope.products.single.basicinfo.id);
                    });
                } else {
                    products.single.alias(scope.products,args.selected).then(function() {
                        myscope.product_single_details(args.selected[0]);
                    });
                }
            }
        };

        myscope.down_key =function(event){
            event.preventDefault();
            event.stopPropagation();
            if(scope.products.current < scope.products.list.length -1) {
                myscope.load_item(scope.products.current +1);
            } else {
                load_page('next').then(function() {
                    myscope.load_item(0);
                },function() {
                    alert("Already at the bottom of the list");
                });
            }
        };
        myscope.up_key = function (event) {
            event.preventDefault();
            event.stopPropagation();
            if(scope.products.current > 0) {
                myscope.load_item(scope.products.current -1);
            } else {
                load_page('previous').then(function() {
                    myscope.load_item(scope.products.list.length -1);
                },function(){
                    alert("Already at the top of the list");
                });
            }
        };

        myscope.add_hotkeys = function() {
            hotkeys.del('up');
            hotkeys.del('down');
            hotkeys.del('esc');
            $timeout(function(){
                hotkeys.bindTo(scope).add({
                    combo: 'up',
                    description: 'Previous product',
                    callback: myscope.up_key
                })
                .add({
                    combo: 'down',
                    description: 'Next product',
                    callback: myscope.down_key
                }).add({
                    combo: 'esc',
                    description: 'Save and close modal',
                    callback: function(){}
                });
            },2000);
        };

        scope.update_single_product = function(post_fn,auto) {
            //console.log(scope.products.single);
            products.single.update(scope.products,auto).then(function() {
                myscope.product_single_details(scope.products.single.basicinfo.id);
            });
        };

        scope.add_warehouse = function(warehouse) {
            scope.products.single.inventory_warehouses.push({warehouse_info:warehouse.info,info:{}});
            scope.update_single_product();
        };

        scope.remove_warehouses = function() {
            var old_warehouses = scope.products.single.inventory_warehouses;
            scope.products.single.inventory_warehouses = [];
            for(var i =0; i < old_warehouses.length;i++) {
                if(!old_warehouses[i].checked) {
                    scope.products.single.inventory_warehouses.push(old_warehouses[i]);
                }
            }
            scope.update_single_product();
        };
        scope.change_opt = function(key,value) {
            scope.general_settings.single[key] = value;
            generalsettings.single.update(scope.general_settings);
        };

        scope.remove_skus_from_kit = function () {
            var selected_skus = [];
            //console.log(scope.products.single.productkitskus);
            for(var i =0; i< scope.products.single.productkitskus.length; i++) {
                if(scope.products.single.productkitskus[i].checked){
                    selected_skus.push(scope.products.single.productkitskus[i].option_product_id);
                }
            }
            products.single.kit.remove(scope.products,selected_skus).then(function(data) {
                myscope.product_single_details(scope.products.single.basicinfo.id);
            });
        };



        myscope.load_item = function(id) {
            myscope.product_single_details(scope.products.list[id].id, true);
            if(myscope.update_state) {
                var newStateParams = angular.copy($stateParams);
                newStateParams.product_id = ""+scope.products.list[id].id;
                $state.go($state.current.name, newStateParams);
            }
        };

        myscope.init = function() {
            scope.translations = {
                "tooltips": {
                    "sku":"",
                    "barcode":"",
                    "confirmation": "",
                    "placement":"",
                    "time_adjust": "",
                    "skippable": "",
                    "record_serial":"",
                    "master_alias":""
                }
            };
            groov_translator.translate('products.modal',scope.translations);


            scope.confirmation_setting_text = "Ask someone with \"Edit General Preferences\" permission to change the setting in <b>General Settings</b> page if you need to override it per product";
            if(auth.can('edit_general_prefs')) {
                scope.general_settings = generalsettings.model.get();
                generalsettings.single.get(scope.general_settings);
                scope.confirmation_setting_text = "<p><strong>You can change the global setting here</strong></p>" +
                     "<div class=\"controls col-sm-offset-4 col-sm-3 \" ng-class=\"{'col-sm-offset-3':general_settings.single.conf_code_product_instruction=='optional' }\" dropdown>"+
                     "<button class=\"dropdown-toggle groove-button label label-default\" ng-class=\"{'label-success':general_settings.single.conf_code_product_instruction=='always'," +
                     " 'label-warning':general_settings.single.conf_code_product_instruction=='optional'}\">" +
                     "<span ng-show=\"general_settings.single.conf_code_product_instruction=='always'\" translate>common.always</span>" +
                     "<span ng-show=\"general_settings.single.conf_code_product_instruction=='optional'\" translate>common.optional</span>" +
                     "<span ng-show=\"general_settings.single.conf_code_product_instruction=='never'\" translate>common.never</span>" +
                     "<span class=\"caret\"></span>" +
                     "</button>" +
                     "<ul class=\"dropdown-menu\" role=\"menu\">" +
                     "<li><a class=\"dropdown-toggle\" ng-click=\"change_opt('conf_code_product_instruction','always')\" translate>common.always</a></li>" +
                     "<li><a class=\"dropdown-toggle\" ng-click=\"change_opt('conf_code_product_instruction','optional')\" translate>common.optional</a></li>" +
                     "<li><a class=\"dropdown-toggle\" ng-click=\"change_opt('conf_code_product_instruction','never')\" translate>common.never</a></li>" +
                     "</ul>"+
                     "</div><div class=\"well-main\">&nbsp;</div>";
            }

            scope.custom_identifier = Math.floor(Math.random()*1000);
            scope.products = product_data;

            /**
             * Public properties
             */
            scope.warehouses = warehouses.model.get();
            warehouses.list.get(scope.warehouses);
            scope.kit_products = products.model.get();
            scope.$watch('products.single.productkitskus',function(){
                if(typeof scope.products.single.basicinfo != "undefined" && scope.products.single.basicinfo.is_kit == 1) {
                    scope.kit_products.list = [];
                    for(var i =0; i<scope.products.single.productkitskus.length; i++) {
                        scope.kit_products.list.push({id:scope.products.single.productkitskus[i].option_product_id});
                    }
                }
            });


            /**
             * private properties
             */
            scope._product_obj = null;
            scope.arrayEditableOptions = {
                array: true,
                update: scope.update_single_product,
                class: '',
                sortableOptions: {
                    update: scope.update_single_product,
                    axis: 'x'
                }
            };

            scope.warehouseGridOptions = {
                identifier:'warehousesgrid',
                selectable:true,
                editable:{
                    update: scope.update_single_product,
                    elements: {
                        available_inv: {type:'number',min:0}
                    }
                },
                all_fields: {
                    name: {
                        name:'Warehouse Name',
                        model: 'row.warehouse_info',
                        editable: false,
                        transclude: '<span>{{row.warehouse_info.name}}</span>'
                    },
                    status: {
                        name: "Status",
                        editable:false,
                        transclude: '<span class="label label-default" ng-class="{\'label-success\': row.warehouse_info.status==\'active\'}">' +
                                    '{{row.warehouse_info.status}}' +
                                    '</span>'
                    },
                    available_inv: {
                        name: 'Available Inv',
                        model:'row.info',
                        transclude: '<span>{{row.info.available_inv}}</span>'
                    },
                    allocated_inv: {
                        name: 'Allocated Inv',
                        model:'row.info',
                        editable:false,
                        transclude: '<span>{{row.info.allocated_inv}}</span>'
                    },
                    sold_inv: {
                        name: 'Sold Inv',
                        model:'row.info',
                        editable:false,
                        transclude: '<span>{{row.info.sold_inv}}</span>'
                    },
                    location_primary: {
                        name: 'Primary Location',
                        model:'row.info',
                        transclude: '<span>{{row.info.location_primary}}</span>'
                    },
                    location_secondary: {
                        name: 'Secondary Location',
                        model:'row.info',
                        transclude: '<span>{{row.info.location_secondary}}</span>'
                    },
                    location_tertiary: {
                        name: 'Tertiary Location',
                        model:'row.info',
                        transclude: '<span>{{row.info.location_tertiary}}</span>'
                    }
                }
            };

            scope.kitEditableOptions = {
                update: scope.update_single_product,
                elements: {
                    qty: {type:'number',min:0},
                    qty_on_hand: {type:'number',min:0},
                    packing_order: {type:'number', min:0}
                },
                functions: {
                    name: scope.load_kit
                }
            };
            myscope.add_hotkeys();

            if(product_id) {
                myscope.update_state = false;
                myscope.product_single_details(product_id,true);
            } else {
                myscope.update_state = true;
                myscope.product_single_details($stateParams.product_id,true);
            }
            $modalInstance.result.then(scope.update,scope.update);
        };
        myscope.init();


        //scope.$on("alias-modal-selected",scope._add_alias_product);
        //$('.icon-question-sign').popover({trigger: 'hover focus'});
        scope.$emit("products-modal-loading-complete",{identifier:scope.custom_identifier});
        scope.$on("products-modal-loading-complete",function(event, args){ if(args.identifier !== scope.custom_identifier) { event.stopPropagation();} });

}]);
