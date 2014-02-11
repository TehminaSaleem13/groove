groovepacks_directives.directive('groovAliasModal',['notification','products','$timeout', function (notification, products,$timeout) {
    return {
        restrict:"A",
        templateUrl:"/assets/partials/aliasmodal.html",
        scope: {
            product_alias:'=groovAliasModal'
        },
        link: function(scope,el,attrs) {

            //Definitions

            /*
             * Public methods
             */
            scope.product_next = function(post_fn) {
                scope._get_products(true,post_fn);
            }

            //Setup options
            scope.handlesort = function(predicate) {
                scope._common_setup_opt('sort',predicate,'product');
            }

            /*
             * Private methods
             */
            //Constructor
            scope._init = function() {
                //Public properties
                scope.products = products.model.get();
                scope.products.setup.limit = 30;
                scope.products.setup.filter = "all";
                scope.custom_identifier = Math.floor(Math.random()*1000);
                scope.is_kit = false;
                scope.selected_aliases = [];

                //Private properties

                scope._alias_obj = null;
                scope._exceptions = [];
                scope._do_load_products = false;
                scope._can_load_products = true;
                //Register watchers
                scope.$watch('products.setup.search',scope._search_products);
                scope.$watch('_can_load_products',scope._can_do_load_products);
            }

            scope.product_alias = function (single) {
                scope._exceptions = [];
                scope.is_kit = single.basicinfo.is_kit;
                scope._exceptions.push(single.basicinfo.id);
                if(scope.is_kit) {
                    for (i in single.productkitskus) {
                        scope._exceptions.push(single.productkitskus[i].option_product_id);
                    }
                }
                scope._get_products();
                if(scope._alias_obj == null) {
                    scope._alias_obj = $('#showAliasOptions'+scope.custom_identifier);
                    scope._alias_obj.on('shown',function() {
                        $("#alias-search-query-"+scope.custom_identifier).focus();
                        scope.selected_aliases = [];
                    });
                }
                scope._alias_obj.modal("show");
            }
            scope.save = function() {
                scope.$emit("alias-modal-selected",{selected: scope.selected_aliases});
                scope._alias_obj.modal("hide");
            }
            scope.add_alias_product = function(product) {
                product.checked = !product.checked;
                if(scope.is_kit) {
                    scope.selected_aliases.push(product.id);
                } else {
                    if(confirm("Are you sure? This can not be undone!")) {
                        scope.selected_aliases.push(product.id);
                        scope.save();
                    }
                }
            }

            scope._get_products = function(next,post_fn) {
                scope._can_load_products = false;
                products.list.get(scope.products,next).then(function(response) {
                    var tmp_list = scope.products.list;
                    scope.products.list = [];
                    for(i in tmp_list) {
                       if(scope._exceptions.indexOf(tmp_list[i].id) == -1 ) {
                           scope.products.list.push(tmp_list[i]);
                       }
                    }
                    if(typeof post_fn == 'function' ) {
                        $timeout(post_fn,30);
                    }
                    scope._can_load_products = true;
                })

            }
            scope._common_setup_opt = function(type,value,selector) {
                products.setup.update(scope.products.setup,type,value);
                scope.products.setup.is_kit = (selector == 'kit')? 1 : 0;
                scope._get_products();
            }


            //Watcher ones
            scope._can_do_load_products = function () {
                if(scope._can_load_products) {
                    if(scope._do_load_products) {
                        scope._do_load_products = false;
                        scope._get_products();
                    }
                }
            }

            scope._search_products = function () {
                if(scope._can_load_products) {
                    scope._get_products();
                } else {
                    scope._do_load_products = true;
                }
            }

            //Definitions end above this line
            /*
             * Initialization
             */
            scope._init();
        }
    };
}]);
