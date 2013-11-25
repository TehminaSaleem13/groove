groovepacks_controllers.
controller('showProductsCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
    	$http.get('/home/userinfo.json').success(function(data){
    		$scope.username = data.username;
    	});
        $('.modal-backdrop').remove();
    	$scope.get_products = function(next) {
            $scope.products_edit_tmp = {
                name:"",
                sku: "",
                status:"",
                barcode:"",
                location:"",
                store:"",
                cat:"",
                editing:-1,
                editing_var: "",
                editing_id:""
            };
            $scope.can_get_products = false;
            next = typeof next !== 'undefined' ? next : false;
            alias = ($scope.trigger_alias || $('#showAliasOptions')[0].clientHeight > 0) ? true : false;
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
                        $scope.alias.products = $scope.temp.products;
                    } else {
                        for(i in $scope.temp.product_setup) {
                            $scope.product_setup[i] = $scope.temp.product_setup[i];
                        }
                        $scope.products = $scope.temp.products;
                    }
                }
                $scope.can_get_products = true;
                $timeout($scope.checkSwapNodes,20);
                $timeout($scope.showHideField,25);
                $scope.showHideField();
            }).error(function(data) {
                $scope.can_get_products = true;
                $timeout($scope.checkSwapNodes,20);
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

        $scope.product_next = function() {
            alias = ($('#showAliasOptions')[0].clientHeight > 0)?  true: false;
            if(alias) {
                $scope.alias.product_setup.offset = $scope.alias.product_setup.offset + $scope.alias.product_setup.limit;
            } else {
                $scope.product_setup.offset = $scope.product_setup.offset + $scope.product_setup.limit;
            }
            $scope.get_products(true);
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
            $scope.products = [];
            $scope.temp = {};
            $scope.temp.products = [];
            $scope.temp.product_setup = {};
            $scope.product_setup.sort = "updated_at";
            $scope.product_setup.order = "DESC";
            $scope.product_setup.filter = "active";
            $scope.product_setup.search = '';
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

            $scope.product_setup.productArray = [];

            /* get user objects of checked items */
            for( i in $scope.products)
            {
                if ($scope.products[i].checked == true) {
                    var product = {};
                    product.id = $scope.products[i].id;
                    product.status = status;
                    $scope.product_setup.productArray.push(product);
                }
            }
            /* update the server with the changed status */
            $http.put('/products/changeproductstatus.json', $scope.product_setup).success(function(data){
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
                    $scope.error_msg = "There was a problem changing products status";
                    $scope.show_error = true;
                    $scope.get_products();
                });
        }
        $scope.product_delete = function() {

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
        $scope.product_single_details = function(id) {
            $scope.single_product = {};
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
                    update = false;
                    if(typeof $scope.single_product.basicinfo.is_skippable == 'undefined' ||
                        ($scope.single_product.basicinfo.is_skippable != true && $scope.single_product.basicinfo.is_skippable != false)
                    ) {
                        $scope.single_product.basicinfo.is_skippable = false;
                        update = true;
                    }
                    if(typeof $scope.single_product.basicinfo.spl_instructions_4_confirmation == 'undefined' ||
                        ($scope.single_product.basicinfo.spl_instructions_4_confirmation != true && $scope.single_product.basicinfo.spl_instructions_4_confirmation != false)
                        ) {
                        $scope.single_product.basicinfo.spl_instructions_4_confirmation = false;
                        update = true;
                    }
                    if(update) {
                        $scope.update_single_product();
                    }
                    $('#showProduct').modal('show');
                }
                //console.log($scope.single_product);
            }).error(function(data) {

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
            //$scope.update_single_product();
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
            //$scope.focus_input('products_'+name+"-"+index);

            console.log(id);
            console.log(index);
            console.log(name);
        }

        $scope.save_single_node = function() { console.log("called");
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

        $scope.update_product_list = function(obj) {
            $http.post('/products/updateproductlist.json',obj).success(function(data){
                console.log(data);
            }).error(function(data) {

            });
        }

        $scope.all_fields = {
            sku: {name:"<i class='icon icon-ok'></i> Sku", className:"rt_field_sku"},
            status:{name:"<i class='icon icon-ok'></i> Status", className:"rt_field_status"},
            barcode:{name:"<i class='icon icon-ok'></i> Barcode", className:"rt_field_barcode"},
            location:{name:"<i class='icon icon-ok'></i> Location", className:"rt_field_location"},
            store:{name:"<i class='icon icon-ok'></i> Store", className:"rt_field_store"},
            cat:{name:"<i class='icon icon-ok'></i> Category", className:"rt_field_cat"}
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
        $scope.update_single_product = function() {
            $http.post('/products/updateproduct.json', $scope.single_product).success(function(data) {
                if(data.status) {
                    $scope.product_update_status = true;
                    $scope.product_update_message = "Successfully Updated";
                } else {
                    $scope.show_error_msgs = true;
                    $scope.error_msgs = ["Some error Occurred"];
                }
            }).error(function() {
                $scope.show_error_msgs = true;
                $scope.error_msgs = ["Some error Occurred"];
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
                    $http.post("products/addproducttokit.json",{product_id: id , kit_id: $scope.single_product.basicinfo.id}).success(
                        function(data) {
                            if(data.status) {
                                $scope.product_update_status = true;
                                $scope.product_update_message = "Successfully Added";
                                $scope.product_single_details($scope.single_product.basicinfo.id);
                            } else {
                                $scope.show_error_msgs = true;
                                $scope.error_msgs = ["Some error Occurred"];
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
            console.log(event.which);
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
            remove:$scope.update_single_product
        };
        $scope.tableSortOptions = {
            start: function (event,ui) {
                console.log(ui.item.sortable.index);
            },
            axis:'x'
        }
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
        $scope.$watch('can_get_products',function() {
            if($scope.can_get_products) {
                if($scope.do_get_products) {
                    $scope.do_get_products = false;
                    $scope.get_products();
                }
            }
        });

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
    }]);
