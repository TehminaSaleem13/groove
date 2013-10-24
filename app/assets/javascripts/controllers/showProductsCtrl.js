groovepacks_controllers.
controller('showProductsCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
    	$http.get('/home/userinfo.json').success(function(data){
    		$scope.username = data.username;
    	});
        $('.modal-backdrop').remove();
    	$scope.get_products = function(next) {
            next = typeof next !== 'undefined' ? next : false;
            if(!next) {
                $scope.product_setup.limit = 10;
                $scope.product_setup.offset = 0;
            }
            if($scope.product_setup.search == '') {
                url = '/products/getproducts.json?filter='+$scope.product_setup.filter+'&sort='+$scope.product_setup.sort+'&order='+$scope.product_setup.order+'&limit='+$scope.product_setup.limit+'&offset='+$scope.product_setup.offset;
            } else {
                url = '/products/search.json?search='+$scope.product_setup.search+'&limit='+$scope.product_setup.limit+'&offset='+$scope.product_setup.offset;
            }
            $http.get(url).success(function(data) {
                if(data.status) {
                    //console.log($scope.product_setup);
                    if(!next) {
                        $scope.products = data.products;
                    } else {
                        for (key in data.products) {
                            $scope.products.push(data.products[key]);
                        }
                    }
                    //console.log($scope.products);
                }
            }).error(function(data) {

            });
        }
        $scope.product_setup_opt = function(type,value) {
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
            }
            $scope.product_setup[type] = value;
            $(".product_setup-"+type).removeClass("active");
            $(".product_setup-"+type+"-"+value).addClass("active");
            $scope.get_products();
        }
        $scope.product_next = function() {
            $scope.product_setup.offset = $scope.product_setup.offset + $scope.product_setup.limit;
            $scope.get_products(true);
        }
        $scope.set_defaults = function() {
            $scope.product_setup = {};
            $scope.products = [];
            $scope.product_setup.sort = "updated_at";
            $scope.product_setup.order = "DESC";
            $scope.product_setup.filter = "active";
            $scope.product_setup.search = '';
            $scope.product_setup.select_all = false;
            $scope.product_setup.limit = 10;
            $scope.product_setup.offset = 0;
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
                category:'cats'
            };
            $http.get('/products/getdetails/'+ id+'.json').success(function(data) {
                console.log(data);
                if(data.product) {
                    $scope.single_product = data.product;
                    $('#showProduct').modal('show');
                }
            }).error(function(data) {

                });
        }
        $scope.handle_key_event =  function(event) {
            //console.log(event);
            name = event.currentTarget.name;
            if(event.keyCode == 13 || event.keyCode == 188 || event.type == "focusout") {
                event.preventDefault();
                if($scope.tmp[name] != "") {
                    $scope.save_node(name,event.type == "focusout");
                }
            }
            if(event.keyCode == 8) {
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
            $("#"+name+"-input").prepend($(".input-text input[name='"+name+"']"));
            $scope.focus_input(name);
            $scope.tmp.editing = -1;
            $scope.tmp.editing_var = -1;
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
            $(".input-text input[name='"+name+"']").focus();
        }
        $scope.blur_input = function(name) {
            $("#name").removeClass("input-text-hover");
            $("#"+name+"-input").addClass("false-tag-bubble");
            $scope.tmp[name] = "";
        }
        $scope.update_single_product = function() {
            $http.post('/products/updateproduct.json', $scope.single_product).success(function(data){
                if(data.status) {
                    console.log(data);
                    
                }
            });
        }

        //Main code ends here. Rest is function calls etc to init
        $scope.set_defaults();
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
            }
        );
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
