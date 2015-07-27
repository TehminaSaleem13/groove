groovepacks_admin_services.factory('tenants',['$http','notification','editable','$window', function($http,notification,editable,$window) {

    // var success_messages = {
    //     update_status: "Status updated Successfully",
    //     delete: "Deleted Successfully",
    //     duplicate: "Duplicated Successfully",
    //     barcode: "Barcodes generated Successfully",
    //     receiving_label: "Labels generated Successfully",
    //     update_per_product: "Updated Successfully"
    // };

    //default object
    var get_default = function() {
        return {
            list: [],
            selected:[],
            single: {},
            current: 0,
            setup:{
                sort: "",
                order: "DESC",
                search: '',
                select_all: false,
                inverted:false,
                limit: 20,
                offset: 0,
                setting:'',
                status:''
            },
            tenants_count: {
            }
        };
    };

    //list related functions
    var get_list = function(tenants,page) {
        return $http.get("/tenants/getinfo.json").success(
            function(data) {
                if(data.status) {
                    tenants.list = data.tenants;
                    tenants.tenants_count = data.tenants.length;
                } else {
                    notification.notify("Can't load list of tenants",0);
                }
            }
        ).error(notification.server_error);
    };

    var get_list = function(tenants,page) {
        var url = '';
        var setup = tenants.setup;
        if(typeof page != 'undefined' && page > 0) {
            page = page - 1;
        } else {
            page = 0;
        }
        tenants.setup.offset = page * tenants.setup.limit;
        if(setup.search=='') {
            url = '/tenants/gettenants.json?&sort='+setup.sort+'&order='+setup.order;
        } else {
            url = '/tenants/search.json?search='+setup.search+'&sort='+setup.sort+'&order='+setup.order;
        }
        url += '&limit='+setup.limit+'&offset='+setup.offset;
        return $http.get(url).success(
            function(data) {
                if(data.status) {
                    tenants.load_new = (data.tenants.length > 0);
                    tenants.tenants_count = data.tenants_count;
                    tenants.list = data.tenants;
                    tenants.current = false;
                    if(tenants.setup.select_all) {
                        tenants.selected = [];
                    }
                    for(var i= 0; i< tenants.list.length; i++) {
                        if(tenants.single && typeof tenants.single['basicinfo'] !="undefined") {
                            if(tenants.list[i].id == tenants.single.basicinfo.id) {
                                tenants.current = i;
                            }
                        }
                        if(tenants.setup.select_all) {
                            tenants.list[i].checked = tenants.setup.select_all;
                            select_single(tenants,tenants.list[i]);
                        } else {
                            for (var j = 0; j < tenants.selected.length; j++) {
                                if (tenants.list[i].id == tenants.selected[j].id) {
                                    tenants.list[i].checked = tenants.selected[j].checked;
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

    var update_setup = function() {

    };

    var total_tenants_list = function(tenants) {
        var total_items;
        if(tenants.setup.search != "") {
            total_items = tenants.tenants_count['search'];
        } else {
            total_items = tenants.tenants_count['all'];
        }
        if(typeof total_items == 'undefined') {
            total_items = 0;
        }
        return total_items;
    };

    var update_list = function(action,products) {
        if(['update_status','delete','duplicate','barcode','receiving_label','update_per_product'].indexOf(action) != -1) {
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
            } else if(action == "receiving_label") {
                url = '/products/print_receiving_label.json';
            } else if(action == 'update_per_product') {
                url = '/products/scan_per_product.json';
            }

            return $http.post(url,products.setup).success(function(data) {
                if(data.status) {
                    notification.notify(success_messages[action],1);
                    products.setup.select_all =  false;
                    products.setup.inverted = false;
                    products.selected = [];
                    if (action == "receiving_label") {
                        $window.open(data.receiving_label_path);
                    }
                } else {
                    notification.notify(data.messages,0);
                }
            }).error(notification.server_error);
        }
    };

    var select_list = function(tenants,from,to,state) {
        var url = '';
        var setup = tenants.setup;
        var from_page = 0;
        var to_page = 0;

        if(typeof from.page != 'undefined' && from.page > 0) {
            from_page = from.page - 1;
        }
        if(typeof to.page != 'undefined' && to.page > 0) {
            to_page = to.page - 1;
        }
        var from_offset = (from_page * setup.limit) + from.index;
        var to_limit = (to_page * setup.limit) + to.index + 1 - from_offset;

        if(setup.search=='') {
            url = '/tenants/gettenants.json?filter='+setup.filter+'&sort='+setup.sort+'&order='+setup.order;
        } else {
            url = '/tenants/search.json?search='+setup.search;
        }
        url += '&is_kit='+setup.is_kit+'&limit='+to_limit+'&offset='+from_offset;
        return $http.get(url).success(function(data) {
            if(data.status) {
                for(var i = 0; i < data.tenants.length; i++) {
                    data.tenants[i].checked = state;
                    select_single(tenants,data.tenants[i]);
                }
            } else {
                notification.notify("Some error occurred in loading the selection.");
            }
        });

    };

    var update_list_node = function(obj) {
        return $http.post('/tenants/updateproductlist.json',obj).success(function(data) {
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
            if(data.product) {
                if(typeof products.single['basicinfo'] != "undefined" && data.product.basicinfo.id == products.single.basicinfo.id) {
                    angular.extend(products.single,data.product);
                } else {
                    products.single = {};
                    products.single = data.product;
                }
            } else {
                products.single = {};
            }
        }).error(notification.server_error).success(editable.force_exit).error(editable.force_exit);
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
        return $http.post('/products/create.json').success(function(data) {
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
        var found = false;
        for(var i = 0; i < products.selected.length; i++) {
            if(products.selected[i].id == row.id) {
                found = i;
                break;
            }
        }

        if(found !== false) {
            if (!row.checked) {
                products.selected.splice(found,1);
            }
        } else {
            if(row.checked) {
                products.selected.push(row);
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
        return $http.post("products/setalias.json",{product_orig_id: ids[0] , product_alias_ids: [products.single.basicinfo.id]}).success(
            function(data) {
                if(data.status) {
                    notification.notify("Successfully Updated",1);
                } else {
                    notification.notify("Some error Occurred",0);
                }
            }
        ).error(notification.server_error);
    };
    var master_alias = function(products,selected) {
        return $http.post("products/setalias.json",{product_orig_id: products.single.basicinfo.id , product_alias_ids: selected}).success(
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

    var acknowledge_activity = function(activity_id) {
        return $http.post('/product_kit_activities/acknowledge/'+activity_id, null).success(function(data) {
            if(data.status) {
                notification.notify("Activity Acknowledged.", 1);
            } else {
                notification.notify(data.messages, 0);
            }
        }).error(notification.server_error);
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
            total_tenants:total_tenants_list,
            update: update_list,
            select: select_list,
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
            master_alias: master_alias,
            reset_obj: reset_single_obj,
            kit:{
                add: add_to_kit,
                remove:remove_from_kit
            },
            activity: {
                acknowledge: acknowledge_activity
            }
        }
    };
}]);
