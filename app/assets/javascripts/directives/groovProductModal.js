groovepacks_directives.directive('groovProductModal',['notification','products','$timeout','$sce', function (notification, products,$timeout,$sce) {
    return {
        restrict:"A",
        templateUrl:"/assets/partials/productmodal.html",
        scope: {
            groovSingleProduct: "=",
            groovProducts: "="
        },
        link: function(scope,el,attrs) {
            scope.custom_identifier = Math.floor(Math.random()*1000);
            /**
             * Public properties
             */
            scope.kit_products = products.model.get();
            scope.$watch('groovProducts.single.basicinfo.is_kit',function(){
                if(typeof scope.groovProducts.single.basicinfo != "undefined" && scope.groovProducts.single.basicinfo.is_kit == 1) {
                    if(scope.kit_modal == "") {
                        scope.kit_modal = $sce.trustAsHtml('<div groov-product-modal groov-products="kit_products" groov-single-product="kit_product_single_details"></div>');
                    }
                    scope.kit_products.list = [];
                    for(i in scope.groovProducts.single.productkitskus) {
                        scope.kit_products.list.push({id:scope.groovProducts.single.productkitskus[i].option_product_id});
                    }
                }
            });
            scope.kit_modal = "";

            /**
             * private properties
             */
            scope._keydown_last = false;
            scope._product_obj = null;

            /**
             * Public methods
             */
            scope.groovSingleProduct = function(id,index,post_fn, open_modal) {
                //console.log(index);
                //console.log(scope.groovProducts);
                if(typeof open_modal == 'boolean' && open_modal ){
                    if(scope._product_obj == null) {
                        scope._product_obj = $("#showProduct"+scope.custom_identifier);
                        scope._product_obj.on('hidden',function(){
                            scope.$emit("products-modal-closed",{identifier: scope.custom_identifier});
                        });
                    }
                    scope._product_obj.modal('show');

                }
                if(typeof index == 'number'){
                    scope.groovProducts.currently_open = index;
                } else {
                    for(i in scope.groovProducts.list) {
                        if(scope.groovProducts.list[i].id == id) {
                            scope.groovProducts.currently_open = parseInt(i);
                            break;
                        }
                    }
                }
                products.single.get(id,scope.groovProducts).then(function(data) {
                    //console.log(scope.groovProducts);
                    if(typeof post_fn == 'function' ) {
                        $timeout(post_fn,10);
                    }
                });
            };
            scope.load_kit = function(id) {
                scope.kit_product_single_details(id,'auto',0,true);
            }
            scope.add_image = function () {
                $("#product_image"+scope.custom_identifier).click();
            }
            scope.remove_image = function(index) {
                scope.groovProducts.single.images.splice(index,1);
                scope.update_single_product();
            }
            scope.$on("fileSelected", function (event, args) {
                $("input[type='file']").val('');
                if(args.name =='product_image') {
                    scope.$apply(function () {
                        products.single.image_upload(scope.groovProducts,args).then(function(response) {
                              scope.groovSingleProduct(scope.groovProducts.single.basicinfo.id,scope.currently_open,0, false);
                        });
                    });
                }
            });

            scope._add_alias_product = function(event,args) {
                event.stopPropagation();
                if(scope.groovProducts.single.basicinfo.is_kit) {
                    products.single.kit.add(scope.groovProducts,args.selected).then(function(response) {
                        //console.log(response.data);
                        scope.groovSingleProduct(scope.groovProducts.single.basicinfo.id,scope.currently_open);
                    });
                } else {
                    products.single.alias(scope.groovProducts,args.selected).then(function() {
                        scope.groovSingleProduct(args.selected[0],'auto');
                    });
                }
            }

            scope.handle_keydown =  function(event) {
                if(event.which == 38) {//up key
                    if(scope.groovProducts.currently_open > 0) {
                        scope.groovSingleProduct(scope.groovProducts.list[scope.groovProducts.currently_open -1].id, scope.groovProducts.currently_open - 1,0, false);
                    } else {
                        alert("Already at the top of the list");
                    }
                } else if(event.which == 40) { //down key
                    //console.log(scope.groovProducts.list.length);
                    //console.log(scope.groovProducts.currently_open);
                    if(scope.groovProducts.currently_open < scope.groovProducts.list.length -1) {
                        scope.groovSingleProduct(scope.groovProducts.list[scope.groovProducts.currently_open + 1].id, scope.groovProducts.currently_open + 1,0, false);
                    } else {
                        scope._keydown_last = true;
                        scope.$emit("products-next-load");
                    }
                }
            };
            scope.update_single_product = function(post_fn,auto) {
                //console.log(scope.groovProducts.single);
                products.single.update(scope.groovProducts,auto).then(function() {
                    scope.groovSingleProduct(scope.groovProducts.single.basicinfo.id,scope.groovProducts.currently_open, post_fn, false);
                });
            };

            scope.add_warehouse = function() {
                var new_warehouse = {
                    alert: "",
                    location: "",
                    name:"",
                    qty: 0,
                    location_primary:"",
                    location_secondary:""
                }
                scope.groovProducts.single.inventory_warehouses.push(new_warehouse);
                scope.update_single_product(function() {
                    scope.$broadcast("warehouse-name-"+(scope.groovProducts.single.inventory_warehouses.length-1));
                });
            }

            scope.remove_warehouses = function() {
                var old_warehouses = scope.groovProducts.single.inventory_warehouses;
                scope.groovProducts.single.inventory_warehouses = [];
                for(i in old_warehouses) {
                    if(!old_warehouses[i].checked) {
                        scope.groovProducts.single.inventory_warehouses.push(old_warehouses[i]);
                    }
                }
                scope.update_single_product();
            }

            scope.remove_skus_from_kit = function () {
                var selected_skus = [];
                //console.log(scope.groovProducts.single.productkitskus);
                for(i in scope.groovProducts.single.productkitskus) {
                    if(scope.groovProducts.single.productkitskus[i].checked){
                        selected_skus.push(scope.groovProducts.single.productkitskus[i].option_product_id);
                    }
                }
                products.single.kit.remove(scope.groovProducts,selected_skus).then(function(data) {
                    scope.groovSingleProduct(scope.groovProducts.single.basicinfo.id,scope.currently_open,0,false);
                });
            }

            scope.arrayEditableOptions = {
                array: true,
                update: scope.update_single_product,
                class: 'span8',
                sortableOptions: {
                    update: scope.update_single_product,
                    axis: 'x'
                }
            };
            scope.editableOptions = {
                update: scope.update_single_product,
                elements: {
                    qty: {type:'number',min:0}
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
            scope.$on("products-next-loaded",function(){
                if(scope._keydown_last) {
                    scope._keydown_last = false;
                    if(scope.groovProducts.currently_open < scope.groovProducts.list -1) {
                        scope.groovSingleProduct(scope.groovProducts.list[scope.groovProducts.currently_open + 1].id, scope.groovProducts.currently_open + 1,0, false);
                    } else {
                        alert("Already at the bottom of the list");
                    }
                }
            });
            scope.$on("products-next-load", function() {
                $timeout(function() {
                    scope.$emit("products-next-loaded");
                },5000);
            });
            scope.$on("alias-modal-selected",scope._add_alias_product);
            scope.$on("products-modal-closed",function(event, args){ if(args.identifier !== scope.custom_identifier) { event.stopPropagation(); scope.groovSingleProduct(scope.groovProducts.single.basicinfo.id,scope.currently_open);} });
            $('.icon-question-sign').popover({trigger: 'hover focus'});
            scope.$emit("product-modal-loading-complete",{identifier:scope.custom_identifier});
            scope.$on("product-modal-loading-complete",function(event, args){ if(args.identifier !== scope.custom_identifier) { event.stopPropagation();} });
        }
    };
}]);
