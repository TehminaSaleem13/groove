groovepacks_controllers.
controller('showProductsCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
    $http.get('/home/userinfo.json').success(function(data){
        $scope.username = data.username;
    });
    $('.modal-backdrop').remove();
    $scope.get_products = function(next,post_fn) {
        //$scope.loading = true;
        $scope.products_edit_tmp = {
            name:"",
            sku: "",
            status:"",
            barcode:"",
            location:"",
            store:"",
            cat:"",
            location_secondary:"",
            location_name:"",
            qty:"",
            editing:-1,
            editing_var: "",
            editing_id:""
        };
        $scope.can_get_products = false;
        next = typeof next !== 'undefined' ? next : false;
        alias = ($scope.trigger_alias || $('#showAliasOptions').hasClass("in")) ? true : false;
        $scope.trigger_alias = false;
        if(alias) {
            $scope.temp.alias = true;
            for(i in $scope.alias.product_setup) {
                $scope.temp.product_setup[i] = $scope.alias.product_setup[i];
            }
            $scope.temp.products = $scope.alias.products;
        } else {
            for(i in $scope.product_setup) {
                $scope.temp.product_setup[i] = $scope.product_setup[i];
            }
            $scope.temp.products = $scope.products;
        }

        if(!next) {
            $scope.temp.product_setup.offset = 0;
        }
        if($scope.temp.product_setup.search == '') {
            url = '/products/getproducts.json?filter='+$scope.temp.product_setup.filter+'&iskit='+$scope.temp.product_setup.is_kit+'&sort='+$scope.temp.product_setup.sort+'&order='+$scope.temp.product_setup.order+'&limit='+$scope.temp.product_setup.limit+'&offset='+$scope.temp.product_setup.offset;
        } else {
            url = '/products/search.json?search='+$scope.temp.product_setup.search+'&iskit='+$scope.temp.product_setup.is_kit+'&limit='+$scope.temp.product_setup.limit+'&offset='+$scope.temp.product_setup.offset;
        }
        $http.get(url).success(function(data) {
            if(data.status) {
                $scope.show_error = false;
                $scope.new_products = (data.products.length > 0);
                if(!next) {
                    $scope.temp.products = data.products;
                } else {
                    for (key in data.products) {
                        $scope.temp.products.push(data.products[key]);
                    }
                }
                if(alias) {
                    for(i in $scope.temp.product_setup) {
                        $scope.alias.product_setup[i] = $scope.temp.product_setup[i];
                    }
                    $scope.alias.products = [];
                    for(i in $scope.temp.products) {
                        if($scope.temp.products[i].id != $scope.single_product.basicinfo.id) {
                            $scope.alias.products.push($scope.temp.products[i]);
                        }
                    }
                } else {
                    for(i in $scope.temp.product_setup) {
                        $scope.product_setup[i] = $scope.temp.product_setup[i];
                    }
                    $scope.products = $scope.temp.products;
                }

            } else {
                $scope.show_error = true;
                $scope.error_msg = "Can't load list of products";
            }
            $scope.can_get_products = true;
            if(typeof post_fn == 'function' ) {
                $timeout(post_fn,30);
            }
            $timeout($scope.checkSwapNodes,20);
            $timeout($scope.showHideField,25);
            $scope.showHideField();
            $scope.loading = false;
            $scope.select_all_toggle();
        }).error(function(data) {
                $scope.show_error = true;
                $scope.error_msg = "Can't load list of products";
            $scope.can_get_products = true;
            $timeout($scope.checkSwapNodes,20);
            if(typeof post_fn == 'function' ) {
                $timeout(post_fn,30);
            }
            $scope.loading = false;
            $scope.select_all_toggle();
        });

    }
    $scope.product_setup_opt = function(type,value) {
        $scope.common_setup_opt(type,value,'product');
    }
    $scope.kit_setup_opt = function(type,value) {
        $scope.common_setup_opt(type,value,'kit');
    }
    $scope.alias_setup_opt = function(type,value) {
        $scope.common_setup_opt(type,value,'alias');
    }
    $scope.common_setup_opt = function(type,value,selector) {
        if(type =='sort') {
            if($scope.product_setup[type] == value) {
                if($scope.product_setup.order == "DESC") {
                    $scope.product_setup.order = "ASC";
                } else {
                    $scope.product_setup.order = "DESC";
                }
            } else {
                $scope.product_setup.order = "DESC";
            }
        } else {
            $scope.product_setup.is_kit = (selector == 'kit')? 1 : 0;
        }
        $scope.product_setup[type] = value;
        $(".product_setup-"+type).removeClass("active");
        $(".kit_setup-"+type).removeClass("active");
        $(".alias_setup-"+type).removeClass("active");
        $('.'+selector+ '_setup-'+type+'-'+value).addClass("active");
        $scope.get_products();
    }

    $scope.product_next = function(post_fn) {
        alias = ($('#showAliasOptions').hasClass("in"))?  true: false;
        if(alias) {
            $scope.alias.product_setup.offset = $scope.alias.product_setup.offset + $scope.alias.product_setup.limit;
        } else {
            $scope.product_setup.offset = $scope.product_setup.offset + $scope.product_setup.limit;
        }
        $scope.get_products(true,post_fn);
    }

    $scope.alias_defaults = function() {
        $scope.alias = {};
        $scope.alias.products = [];
        $scope.alias.product_setup = {};
        $scope.alias.product_setup.sort = "updated_at";
        $scope.alias.product_setup.order = "DESC";
        $scope.alias.product_setup.filter = "all";
        $scope.alias.product_setup.search = '';
        $scope.alias.product_setup.select_all = false;
        $scope.alias.product_setup.is_kit = 0;
        $scope.alias.product_setup.limit = 30;
        $scope.alias.product_setup.offset = 0;
    }
    $scope.set_defaults = function() {
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
        $scope.product_setup.sort = "updated_at";
        $scope.product_setup.order = "DESC";
        $scope.product_setup.filter = "active";
        $scope.product_setup.search = '';
        $scope.product_setup.status = '';
        $scope.product_setup.select_all = false;
        $scope.product_setup.is_kit = 0;
        $scope.product_setup.limit = 20;
        $scope.product_setup.offset = 0;
        $scope.alias_defaults();
        $(".product_setup-filter-active").addClass("active");
        $scope.get_products();
    }
    $scope.select_all_toggle = function() {
        //$scope.product_setup.select_all = !$scope.product_setup.select_all;
        for (i in $scope.products) {
            $scope.products[i].checked =  $scope.product_setup.select_all;
        }
    }
    $scope.product_change_status = function(status) {
        $scope.loading = true;
        $scope.product_setup.productArray = [];
        $scope.product_setup.status = status;

        /* get user objects of checked items */
        for( i in $scope.products)
        {
            if ($scope.products[i].checked == true) {
                var product = {};
                product.id = $scope.products[i].id;
                $scope.product_setup.productArray.push(product);
            }
        }
        /* update the server with the changed status */
        $http.put('/products/changeproductstatus.json', $scope.product_setup).success(function(data){
            $scope.product_setup.status = "";
            if (data.status)
            {
                $scope.product_setup.select_all = false;

            }
            else
            {
                $scope.error_msg = "There was a problem changing products status";
                $scope.show_error = true;
            }
            $scope.get_products();
        }).error(function(data){
                $scope.product_setup.status = "";
                $scope.error_msg = "There was a problem changing products status";
                $scope.show_error = true;
                $scope.get_products();
            });
    }
    $scope.product_delete = function() {
        $scope.loading = true;
        $scope.product_setup.productArray = [];

        /* get user objects of checked items */
        for( i in $scope.products)
        {
            if ($scope.products[i].checked == true) {
                var product = {};
                product.id = $scope.products[i].id;
                $scope.product_setup.productArray.push(product);
            }
        }
        /* update the server with the changed status */
        $http.put('/products/deleteproduct.json', $scope.product_setup).success(function(data){
            $scope.get_products();
            if (data.status)
            {
                $scope.product_setup.select_all = false;
                $scope.get_products();
            }
            else
            {
                $scope.error_msg = data.message;
                $scope.show_error = true;
            }

        }).error(function(data){
                $scope.error_msg = data.message;
                $scope.show_error = true;
                $scope.get_products();
            });
    }
    $scope.product_duplicate = function() {
        $scope.loading = true;
        $scope.product_setup.productArray = [];

        /* get user objects of checked items */
        for( i in $scope.products)
        {
            if ($scope.products[i].checked == true) {
                var product = {};
                product.id = $scope.products[i].id;
                $scope.product_setup.productArray.push(product);
            }
        }
        /* update the server with the changed status */
        $http.put('/products/duplicateproduct.json', $scope.product_setup).success(function(data){
            $scope.get_products();
            if (data.status)
            {
                $scope.product_setup.select_all = false;
            }
            else
            {
                $scope.error_msg = data.message;
                $scope.show_error = true;
            }
        }).error(function(data){
                $scope.error_msg = data.message;
                $scope.show_error = true;
                $scope.get_products();
            });
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

    $scope.edit_single_node = function(index,id,name) {
        $scope.save_single_node();
        $scope.products_edit_tmp.editing_var = name;
        $scope.products_edit_tmp.editing = index;
        $scope.products_edit_tmp.editing_id = id;
        $scope.products_edit_tmp[name] = $scope.products[index][name];
        $scope.products[index][name] = "";
        $timeout(function() {$scope.focus_input('products_'+name+"_"+index);},10);
    }

    $scope.save_single_node = function() {
        if($scope.products_edit_tmp.editing != -1 ) {
            $scope.products[$scope.products_edit_tmp.editing][$scope.products_edit_tmp.editing_var] = $scope.products_edit_tmp[$scope.products_edit_tmp.editing_var];
            $scope.update_product_list(
                {
                    id: $scope.products_edit_tmp.editing_id,
                    var:$scope.products_edit_tmp.editing_var,
                    value: $scope.products[$scope.products_edit_tmp.editing][$scope.products_edit_tmp.editing_var]
                }
            );
        }
        $scope.products_edit_tmp.editing_var = "";
        $scope.products_edit_tmp.editing = -1;
        $scope.products_edit_tmp.editing_id = -1;
    }

    $scope.edit_warehouse_node = function(index,id,name) {

        $scope.save_warehouse_node();
        $scope.warehouse_edit_tmp.editing_var = name;
        $scope.warehouse_edit_tmp.editing = index;
        $scope.warehouse_edit_tmp.editing_id = id;
        $scope.warehouse_edit_tmp[name] = $scope.single_product.inventory_warehouses[index][name];
        $scope.single_product.inventory_warehouses[index][name] = "";
        $timeout(function(){$scope.focus_input('warehouse_'+name+"_"+index);},20);
    }

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
    $scope.update_product_list = function(obj) {
        $scope.loading = true;
        $http.post('/products/updateproductlist.json',obj).success(function(data){
            if(data.status) {
                $scope.show_error = false;
                $scope.show_error_msgs = false;
            } else {
                $scope.show_error = true;
                $scope.error_msg = data.error_msg;
            }
            $scope.get_products();

        }).error(function(data) {
            $scope.show_error = true;
            $scope.error_msg = "Couldn't save product info";
            $scope.get_products();
        });
    }

    $scope.all_fields = {
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
    $scope.shown_fields = ["checkbox","name","sku","status","barcode","location","store"];

    $scope.showHideField = function(key,options) {
        $(".context-menu-item i").removeClass("icon-ok").addClass("icon-remove");
        $("#productstbl th, #productstbl td").hide();
        var array_position = $scope.shown_fields.indexOf(key);
        if(array_position > -1) {
            $scope.shown_fields.splice( array_position, 1 );
        } else {
            $scope.shown_fields.push(key);
        }
        for (i in $scope.shown_fields) {
            $(".rt_field_"+$scope.shown_fields[i]+" i").removeClass("icon-remove").addClass("icon-ok");
            $("[data-header='"+$scope.shown_fields[i]+"']").show();
        }
    }

    $.contextMenu({
        // define which elements trigger this menu
        selector: "#productstbl thead",
        // define the elements of the menu
        items: $scope.all_fields,
        // there's more, have a look at the demos and docs...
        callback: $scope.showHideField
    });
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
    $scope.product_alias = function () {
        $scope.alias_defaults();
        $scope.new_products = true;
        $('#showAliasOptions').modal("show");
        $scope.trigger_alias = true;
        $scope.get_products();
    }
    $scope.add_alias_product = function(id) {
        if(confirm("Are you sure? This can not be undone!")) {
            if($scope.single_product.basicinfo.is_kit) {
                $http.post("/products/addproducttokit.json",{product_id: id , kit_id: $scope.single_product.basicinfo.id}).success(
                    function(data) {
                        //console.log(data);
                        if(data.status) {
                            $scope.product_update_status = true;
                            $scope.show_error_msgs = false;
                            $scope.product_update_message = "Successfully Added";
                            $scope.product_single_details($scope.single_product.basicinfo.id);
                        } else {
                            $scope.show_error_msgs = true;
                            $scope.error_msgs = data.messages;
                        }
                    }
                ).error(function(data){
                        $scope.show_error_msgs = true;
                        $scope.error_msgs = ["Some error Occurred"];
                    });
            } else {

                $http.post("products/setalias.json",{product_orig_id: id , product_alias_id: $scope.single_product.basicinfo.id}).success(
                    function(data) {
                        if(data.status) {
                            $scope.product_update_status = true;
                            $scope.show_error_msgs = false;
                            $scope.product_update_message = "Successfully Updated";
                            $scope.product_single_details(id);
                        } else {
                            $scope.show_error_msgs = true;
                            $scope.error_msgs = ["Some error Occurred"];
                        }
                    }
                ).error(function(data){
                        $scope.show_error_msgs = true;
                        $scope.error_msgs = ["Some error Occurred"];
                    });
            }
        }
        $('#showAliasOptions').modal("hide");
    }
    $scope.select_deselect_kit_sku = function(option_product_id,index){
        var array_position = $scope.selected_skus.indexOf(option_product_id);
        $(".kit_sku").removeClass("info");
        if(array_position > -1) {
            $scope.selected_skus[index] = "";
        } else {
            $scope.selected_skus[index] = option_product_id;
        }
        //console.log($scope.selected_skus);
        for(i in $scope.selected_skus) {
            if($scope.selected_skus[i] !=="") {
                $(".kit_sku_"+i).addClass("info");
            }
        }
    }
    $scope.remove_skus_from_kit = function () {

        $http.post('/products/removeproductsfromkit.json',{kit_id: $scope.single_product.basicinfo.id, kit_products: $scope.selected_skus }).success(function(data){
            if(data.status) {
                $scope.product_update_status = true;
                $scope.show_error_msgs = false;
                $scope.product_update_message = "Successfully Removed";
                $scope.product_single_details($scope.single_product.basicinfo.id);
            } else {
                $scope.show_error_msgs = true;
                $scope.error_msgs = data.messages;
            }
        }).error(function(data){
                $scope.show_error_msgs = true;
                $scope.error_msgs = ["Some error Occurred"];
        });

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
        if($('#showProduct').hasClass("in") &&  !$('#showAliasOptions').hasClass("in")) {
            //console.log("keypress "+event.which);
            //console.log("Product Len");
            //console.log($scope.products.length);
            //console.log("Current Open");
            //console.log($scope.currently_open);
            if(event.which == 38) {//up key
                if($scope.currently_open > 0) {
                    $scope.product_single_details($scope.products[$scope.currently_open -1].id, $scope.currently_open - 1);
                } else {
                    alert("Already at the top of the list");
                }
            } else if(event.which == 40) { //down key
                if($scope.currently_open < $scope.products.length -1) {
                    $scope.product_single_details($scope.products[$scope.currently_open + 1].id, $scope.currently_open + 1);
                } else {
                    $scope.product_next(function(){
                        if($scope.currently_open < $scope.products.length -1) {
                            $scope.product_single_details($scope.products[$scope.currently_open + 1].id, $scope.currently_open + 1);
                        } else {
                            alert("Already at the bottom of the list");
                        }
                    });
                }
            }

        }
    }

    $scope.checkSwapNodes = function() {
        var node_order_array = [];
        $('#productstbl thead tr').children('th').each(function(index){node_order_array[this.getAttribute('data-header')] = index;});
        $('#productstbl tbody tr ').each(
            function(index){
                var children = this.children;
                for (i=0; i <children.length; i++) {
                    if( node_order_array[children[i].getAttribute('data-header')] != i) {
                       $scope.doRealSwap(children[i],children[node_order_array[children[i].getAttribute('data-header')]]);
                    }
                }
            }
        );
    }
    $scope.doRealSwap = function swapNodes(a, b) {
        var aparent = a.parentNode;
        var asibling = a.nextSibling === b ? a : a.nextSibling;
        b.parentNode.insertBefore(a, b);
        aparent.insertBefore(b, asibling);
    }

    //Main code ends here. Rest is function calls etc to init
    $scope.set_defaults();
    $('#productstbl').dragtable({dragaccept:'.product_setup-sort',clickDelay:250});
    $scope.sortableOptions = {
        update:$scope.update_single_product,
        axis: 'x'
    };

    $scope.$watch('product_update_status',function() {
        if($scope.product_update_status) {
            $("#product_update_status").fadeTo("fast",1,function() {
                $("#product_update_status").fadeTo("slow", 0 ,function() {
                    $scope.product_update_status = false;
                });
            });
        }
    });

    $scope.$watch('alias.product_setup.search',function() {
        if($scope.can_get_products) {
            $scope.get_products();
        } else {
            $scope.do_get_products = true;
        }
    });
    $scope.$watch('product_setup.search',function() {
        if($scope.can_get_products) {
            $scope.get_products();
        } else {
            $scope.do_get_products = true;
        }
    });
    $scope.$watch('can_get_products',function() {
        if($scope.can_get_products) {
            if($scope.do_get_products) {
                $scope.do_get_products = false;
                $scope.get_products();
            }
        }
    });
    $('#showProduct').on('hidden',function(){$scope.get_products()}).keydown($scope.keyboard_nav_event);
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
    $("#product-search-query").focus();
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
}]);
