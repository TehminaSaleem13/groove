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

    var update_setup = function(setup,type,value) {
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

    var select_single = function(tenants,row) {
        var found = false;
        for(var i = 0; i < tenants.selected.length; i++) {
            if(tenants.selected[i].id == row.id) {
                found = i;
                break;
            }
        }

        if(found !== false) {
            if (!row.checked) {
                tenants.selected.splice(found,1);
            }
        } else {
            if(row.checked) {
                tenants.selected.push(row);
            }
        }
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
            select: select_list,
            update_node: update_list_node
        },
        single: {
            select: select_single
        }
    };
}]);
