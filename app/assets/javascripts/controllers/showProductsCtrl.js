groovepacks_controllers.
controller('showProductsCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies','products',
function( $scope, $http, $timeout, $routeParams, $location, $route, $cookies,products) {
    //Definitions

    /*
     * Public methods
     */
    $scope.product_next = function(post_fn) {
        $scope._get_products(true,post_fn);
    }

    $scope.select_all_toggle = function() {
        for (i in $scope.products.list) {
            $scope.products.list[i].checked =  $scope.products.setup.select_all;
        }
    }
    $scope.update_product_list = function(product,prop) {
        products.list.update_node({
            id: product.id,
            var: prop,
            value: product[prop]
        }).then($scope._get_products)
    }

    //Setup options
    $scope.product_setup_opt = function(type,value) {
        $scope._common_setup_opt(type,value,'product');
    }
    $scope.kit_setup_opt = function(type,value) {
        $scope._common_setup_opt(type,value,'kit');
    }

    $scope.handlesort = function(predicate) {
        $scope._common_setup_opt('sort',predicate,'product');
    }

    $scope.product_change_status = function(status) {
        $scope.products.setup.status = status;
        products.list.update('update_status',$scope.products).then(function(data) {
            $scope.products.setup.status = "";
            $scope._get_products();
        });
    }
    $scope.product_delete = function() {
        products.list.update('delete',$scope.products).then(function(data) {
            $scope._get_products();
        });
    }
    $scope.product_duplicate = function() {
        products.list.update('duplicate',$scope.products).then(function(data) {
            $scope._get_products();
        });
    }


    /*
     * Private methods
     */
    //Constructor
    $scope._init = function() {
        //Public properties
        $scope.products = products.model.get();
        $scope.aliases = products.model.get();
        $scope.aliases.setup.limit = 30;
        $scope.aliases.setup.filter = "all";
        $scope.editableOptions = {
            array:false,
            update: $scope.update_product_list,
            elements: {
                status: {
                    type:'select',
                    options:[
                        {name:"Active",value:'active'},
                        {name:"Inactive",value:'inactive'},
                        {name:"New",value:'new'}
                    ]
                },
                qty:{
                    type:'number',
                    min:0
                }
            },
            functions: {
                name: function(id,index,post_fn,open_modal) {
                    $scope.product_single_details(id,index,post_fn,open_modal);
                }
            }

        };

        //Private properties

        $scope._do_load_products = false;
        $scope._can_load_products = true;
        $scope._all_fields = {
            sku: {name:"<i class='icon icon-ok'></i> Sku", className:"rt_field_sku"},
            status:{name:"<i class='icon icon-ok'></i> Status", className:"rt_field_status"},
            barcode:{name:"<i class='icon icon-ok'></i> Barcode", className:"rt_field_barcode"},
            location:{name:"<i class='icon icon-ok'></i> Primary Location", className:"rt_field_location"},
            store:{name:"<i class='icon icon-ok'></i> Store", className:"rt_field_store"},
            cat:{name:"<i class='icon icon-ok'></i> Category", className:"rt_field_cat"},
            location_secondary:{name:"<i class='icon icon-ok'></i> Secondary Location", className:"rt_field_location_secondary"},
            location_name:{name:"<i class='icon icon-ok'></i> Warehouse Name", className:"rt_field_location_name"},
            qty:{name:"<i class='icon icon-ok'></i> Quantity", className:"rt_field_qty"}
        };
        $scope._shown_fields = ["checkbox","name","sku","status","barcode","location","store"];


        //Register events and make function calls
        $.contextMenu({
            // define which elements trigger this menu
            selector: "#productstbl thead",
            // define the elements of the menu
            items: $scope._all_fields,
            // there's more, have a look at the demos and docs...
            callback: $scope._showHideField
        });
        $('#productstbl').dragtable({dragaccept:'.dragtable-sortable',clickDelay:250});

        //Register watchers
        $scope.$watch('products.setup.search',$scope._search_products);
        $scope.$watch('_can_load_products',$scope._can_do_load_products);

        $scope.$on("products-modal-closed",function(event, args){event.stopPropagation(); $scope._get_products();});
        $scope.$on("products-next-load",function(event, args){$scope.product_next(function(){ $scope.$broadcast("products-next-loaded");});});

        $http.get('/home/userinfo.json').success(function(data){
            $scope.username = data.username;
        });
        $('.modal-backdrop').remove();
        $("#product-search-query").focus();
    }

    $scope._get_products = function(next,post_fn) {
        $scope._can_load_products = false;
        products.list.get($scope.products,next).then(function(response) {
            //console.log("got products");
            if(typeof post_fn == 'function' ) {
                //console.log("triggering post function on get products");
                $timeout(post_fn,30);
            }
            $timeout($scope._checkSwapNodes,20);
            $timeout($scope._showHideField,25);
            $scope.select_all_toggle();
            $scope._can_load_products = true;
        })

    }
    $scope._common_setup_opt = function(type,value,selector) {
        products.setup.update($scope.products.setup,type,value);
        $scope.products.setup.is_kit = (selector == 'kit')? 1 : 0;
        $scope._get_products();
    }

    $scope._checkSwapNodes = function() {
        var node_order_array = [];
        $('#productstbl thead tr').children('th').each(function(index){node_order_array[this.getAttribute('data-header')] = index;});
        $('#productstbl tbody tr ').each(
            function(index){
                var children = this.children;
                for (i=0; i <children.length; i++) {
                    if( node_order_array[children[i].getAttribute('data-header')] != i) {
                        $scope._doRealSwap(children[i],children[node_order_array[children[i].getAttribute('data-header')]]);
                    }
                }
            }
        );
    }

    $scope._doRealSwap = function swapNodes(a, b) {
        var aparent = a.parentNode;
        var asibling = a.nextSibling === b ? a : a.nextSibling;
        b.parentNode.insertBefore(a, b);
        aparent.insertBefore(b, asibling);
    }

    $scope._showHideField = function(key,options) {
        $(".context-menu-item i").removeClass("icon-ok").addClass("icon-remove");
        $("#productstbl th, #productstbl td").hide();
        var array_position = $scope._shown_fields.indexOf(key);
        if(array_position > -1) {
            $scope._shown_fields.splice( array_position, 1 );
        } else {
            $scope._shown_fields.push(key);
        }
        for (i in $scope._shown_fields) {
            $(".rt_field_"+$scope._shown_fields[i]+" i").removeClass("icon-remove").addClass("icon-ok");
            $("[data-header='"+$scope._shown_fields[i]+"']").show();
        }
        return false;
    }

    //Watcher ones
    $scope._can_do_load_products = function () {
        if($scope._can_load_products) {
            if($scope._do_load_products) {
                $scope._do_load_products = false;
                //console.log("can do load triggered");
                $scope._get_products();
            }
        }
    }

    $scope._search_products = function () {
        if($scope._can_load_products) {
            $scope._get_products();
        } else {
            $scope._do_load_products = true;
        }
    }

    //Definitions end above this line
    /*
     * Initialization
     */
    //Main code ends here. Rest is function calls etc to init
    $scope._init();
}]);
