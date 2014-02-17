groovepacks_services.factory('products',['$http','notification',function($http,notification) {

    var success_messages = {
        update_status: "Status updated Successfully",
        delete:"Deleted Successfully",
        duplicate: "Duplicated Successfully"
    };

    //default object
    var get_default = function() {
        return {
            list: [],
            single: {},
            load_new: true,
            current: 0,
            setup:{
                sort: "updated_at",
                order: "DESC",
                filter: "active",
                search: '',
                select_all: false,
                is_kit: 0,
                limit: 20,
                offset: 0,
                //used for updating only
                status:'',
                productArray:[]
            }
        };
    }

    //Setup related function
    var update_setup = function (setup,type,value) {
        if(type =='sort') {
            if(setup[type] == value) {
                if(setup.order == "DESC") {
                    setup.order = "ASC";
                } else {
                    setup.order = "DESC";
                }
            } else {
                setup.order = "DESC";
            }
        }
        setup[type] = value;
        return setup;
    };

    //list related functions
    var get_list = function(object,next) {
        var url = '';
        var setup = object.setup;
        next = typeof next !== 'undefined' ? next : false;
        if(!next) {
            object.setup.offset = 0;
        } else {
            object.setup.offset = object.setup.offset + object.setup.limit;
        }
        if(setup.search=='') {
            url = '/products/getproducts.json?filter='+setup.filter+'&sort='+setup.sort+'&order='+setup.order;
        } else {
            url = '/products/search.json?search='+setup.search
        }
        url += '&iskit='+setup.is_kit+'&limit='+setup.limit+'&offset='+setup.offset;
        return $http.get(url).success(
            function(data) {
                if(data.status) {
                    object.load_new = (data.products.length > 0);
                    if(!next) {
                        object.list = data.products;
                    } else {
                        for (key in data.products) {
                            object.list.push(data.products[key]);
                        }
                    }
                } else {
                    notification.notify("Can't load list of products",0);
                }
            }
        ).error(notification.server_error);
    }

    var update_list = function(action,products) {
        if(["update_status","delete","duplicate"].indexOf(action) != -1) {
            products.setup.productArray = [];
            for( i in products.list) {
                if (products.list[i].checked == true) {
                    products.setup.productArray.push({id: products.list[i].id});
                }
            }
            var url = '';
            if(action == "delete") {
                url = '/products/deleteproduct.json';
            } else if(action =="duplicate") {
                url = '/products/duplicateproduct.json';
            } else if(action == "status_update") {
                url = '/products/changeproductstatus.json';
            }

            return $http.post(url,products.setup).success(function(data) {
                if(data.status) {
                    notification.notify(success_messages[action],1);
                    products.setup.select_all =  false;
                } else {
                    notification.notify(data.messages,0);
                }
            }).error(notification.server_error);
        }
    }

    var update_list_node = function(obj) {
        return $http.post('/products/updateproductlist.json',obj).success(function(data){
            if(data.status) {
                notification.notify("Successfully Updated",1);
            } else {
                notification.notify(data.error_msg,0);
            }
        }).error(notification.server_error);
    }

    //single product related functions
    var get_single = function(id,products) {
        return $http.get('/products/getdetails/'+ id+'.json').success(function(data) {
            products.single = {};
            if(data.product) {
                products.single = data.product;
            }
        });
    }

    var update_single = function(products,auto) {
        if(typeof auto !== "boolean") {
            auto = true;
        }
        return $http.post('/products/updateproduct.json', products.single).success(function(data) {
            if(data.status) {
                if(!auto) {
                    notification.notify("Successfully Updated",1);
                }
            } else {
                if(data.message) {
                    notification.notify(data.message,0);
                } else {
                    notification.notify("Some error Occurred",0);
                }
            }
        }).error(notification.server_error);
    }

    var add_image = function(products,image) {
        return $http({
        method: 'POST',
        headers: { 'Content-Type': undefined },
        url:'/products/addimage.json',
        transformRequest: function (data) {
            var request = new FormData();
            for (var key in data) {
                request.append(key,data[key]);
            }
            return request;
        },
        data: {product_id: products.single.basicinfo.id, product_image: image.file}
        }).success(function(data) {
            if(data.status) {
                notification.notify("Successfully Updated",1);

            } else {
                notification.notify("Some error Occurred",0);
            }

        }).error(notification.server_error);
    };

    var set_alias = function (products,ids) {
        return $http.post("products/setalias.json",{product_orig_id: ids[0] , product_alias_id: products.single.basicinfo.id}).success(
            function(data) {
                if(data.status) {
                    notification.notify("Successfully Updated",1);
                } else {
                    notification.notify("Some error Occurred",0);
                }
            }
        ).error(notification.server_error);
    };

    var add_to_kit = function(kits,ids) {
        return $http.post("/products/addproducttokit.json",{product_ids: ids , kit_id: kits.single.basicinfo.id}).success(
            function(data) {
                if(data.status) {
                    notification.notify("Successfully Added",1);
                } else {
                    notification.notify(data.messages,0);
                }
            }
        ).error(notification.server_error);
    };

    var remove_from_kit = function(products,skus) {
        return $http.post('/products/removeproductsfromkit.json',{kit_id: products.single.basicinfo.id, kit_products: skus }).success(function(data){
            if(data.status) {
                notification.notify("Successfully Removed",1);
            } else {
                notification.notify(data.messages,0);
            }
        }).error(notification.server_error);
    }


    //Public facing API
    return {
        model: {
            get:get_default
        },
        setup: {
            update:update_setup
        },
        list: {
            get: get_list,
            update: update_list,
            update_node: update_list_node
        },
        single: {
            get: get_single,
            update:update_single,
            image_upload: add_image,
            alias: set_alias,
            kit:{
                add: add_to_kit,
                remove:remove_from_kit
            }
        }
    };
}]);
