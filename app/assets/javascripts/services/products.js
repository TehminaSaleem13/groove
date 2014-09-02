groovepacks_services.factory('products',['$http','notification',function($http,notification) {

    var success_messages = {
        update_status: "Status updated Successfully",
        delete: "Deleted Successfully",
        duplicate: "Duplicated Successfully",
        barcode: "Barcodes generated Successfully"
    };

    //default object
    var get_default = function() {
        return {
            list: [],
            selected:[],
            single: {},
            load_new: true,
            current: 0,
            setup:{
                sort: "",
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
            },
            products_count: {
            }
        };
    };

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
    var get_list = function(object,page) {
        var url = '';
        var setup = object.setup;
        if(typeof page != 'undefined' && page > 0) {
            page = page - 1;
        } else {
            page = 0;
        }
        object.setup.offset = page * object.setup.limit;
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
                    object.products_count = data.products_count;
                    object.list = data.products;
                    object.current = false;
                    if(object.setup.select_all) {
                        object.selected = [];
                    }
                    for(var i= 0; i< object.list.length; i++) {
                        if(object.single && typeof object.single['basicinfo'] !="undefined") {
                            if(object.list[i].id == object.single.basicinfo.id) {
                                object.current = i;
                            }
                        }
                        if(object.setup.select_all) {
                            object.list[i].checked = object.setup.select_all;
                            select_single(object,object.list[i]);
                        } else {
                            for (var j = 0; j < object.selected.length; j++) {
                                if (object.list[i].id == object.selected[j].id) {
                                    object.list[i].checked = object.selected[j].checked;
                                    break;
                                }
                            }
                        }
                    }
                } else {
                    notification.notify("Can't load list of products",0);
                }
            }
        ).error(notification.server_error);
    };

    var total_items_list = function(products) {
        var total_items;
        if(products.setup.search != "") {
            total_items = products.products_count['search'];
        } else {
            total_items = products.products_count[products.setup['filter']];
        }
        if(typeof total_items == 'undefined') {
            total_items = 0;
        }
        return total_items;
    };

    var update_list = function(action,products) {
        if(["update_status","delete","duplicate","barcode"].indexOf(action) != -1) {
            products.setup.productArray = [];
            for(var i =0; i < products.selected.length; i++) {
                if (products.selected[i].checked == true) {
                    products.setup.productArray.push({id: products.selected[i].id});
                }
            }
            var url = '';
            if(action == "delete") {
                url = '/products/deleteproduct.json';
            } else if(action =="duplicate") {
                url = '/products/duplicateproduct.json';
            } else if(action == "update_status") {
                url = '/products/changeproductstatus.json';
            } else if(action == "barcode") {
                url = '/products/generatebarcode.json';
            }

            return $http.post(url,products.setup).success(function(data) {
                if(data.status) {
                    notification.notify(success_messages[action],1);
                    products.setup.select_all =  false;
                    products.selected = [];
                } else {
                    notification.notify(data.messages,0);
                }
            }).error(notification.server_error);
        }
    };

    var update_list_node = function(obj) {
        return $http.post('/products/updateproductlist.json',obj).success(function(data){
            if(data.status) {
                notification.notify("Successfully Updated",1);
            } else {
                notification.notify(data.error_msg,0);
            }
        }).error(notification.server_error);
    };

    //single product related functions
    var get_single = function(id,products) {
        return $http.get('/products/getdetails/'+ id+'.json').success(function(data) {
            products.single = {};
            if(data.product) {
                products.single = data.product;
            }
        }).error(notification.server_error);
    };

    //single product retrieval by barcode
    var get_single_product_by_barcode = function(barcode,products) {
        return $http.get('/products/getdetails.json?barcode='+barcode).success(function(data) {
            products.single = {};
            if(data.product) {
                products.single = data.product;
            }
            else {
               notification.notify('Cannot find product with barcode: '+barcode, 0); 
            }
        }).error(notification.server_error);
    };

    var create_single = function(products) {
        return $http.post('/products/create.json').success(function(data){
            products.single = {};
            if(!data.status) {
                notification.notify(data.messages,0);
            }
        }).error(notification.server_error);
    };
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
    };

    var select_single = function(products,row) {
        if(row.checked) {
            products.selected.push(row);
        } else {
            for(var i = 0; i < products.selected.length; i++) {
                if(products.selected[i].id == row.id) {
                    products.selected.splice(i,1);
                    break;
                }
            }
        }
    };

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
    };

    var reset_single_obj = function(products) {
        products.single = {};
    };

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
            total_items:total_items_list,
            update: update_list,
            update_node: update_list_node
        },
        single: {
            get: get_single,
            get_by_barcode: get_single_product_by_barcode,
            create:create_single,
            update:update_single,
            select: select_single,
            image_upload: add_image,
            alias: set_alias,
            reset_obj: reset_single_obj,
            kit:{
                add: add_to_kit,
                remove:remove_from_kit
            }
        }
    };
}]);
