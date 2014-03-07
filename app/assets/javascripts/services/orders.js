groovepacks_services.factory('orders',['$http','notification',function($http,notification) {

    var success_messages = {
        update_status: "Status updated Successfully",
        delete:"Deleted Successfully",
        duplicate: "Duplicated Successfully"
    };

    var get_default = function() {
        return {
            list: [],
            single: {},
            load_new: true,
            current: 0,
            setup:{
                sort: "updated_at",
                order: "DESC",
                filter: "awaiting",
                search: '',
                select_all: false,
                limit: 20,
                offset: 0,
                //used for updating only
                status:'',
                orderArray:[]
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
        next = typeof next == 'boolean' ? next : false;
        if(!next) {
            object.setup.offset = 0;
        } else {
            object.setup.offset = object.setup.offset + object.setup.limit;
        }
        if(setup.search=='') {
            url = '/orders/getorders.json?filter='+setup.filter+'&sort='+setup.sort+'&order='+setup.order;
        } else {
            url = '/orders/search.json?search='+setup.search;
        }
        url += '&limit='+setup.limit+'&offset='+setup.offset;
        return $http.get(url).success(
            function(data) {
                if(data.status) {
                    object.load_new = (data.orders.length > 0);
                    if(!next) {
                        object.list = data.orders;
                    } else {
                        for (key in data.orders) {
                            object.list.push(data.orders[key]);
                        }
                    }
                } else {
                    notification.notify("Can't load list of orders",0);
                }
            }
        ).error(notification.server_error);
    }

    var update_list = function(action,orders) {
        if(["update_status","delete","duplicate"].indexOf(action) != -1) {
            orders.setup.orderArray = [];
            for( i in orders.list) {
                if (orders.list[i].checked == true) {
                    orders.setup.orderArray.push({id: orders.list[i].id});
                }
            }
            var url = '';
            if(action == "delete") {
                url = '/orders/deleteorder.json';
            } else if(action =="duplicate") {
                url = '/orders/duplicateorder.json';
            } else if(action == "update_status") {
                url = '/orders/changeorderstatus.json';
            }

            return $http.post(url,orders.setup).success(function(data) {
                if(data.status) {
                    orders.setup.select_all =  false;
                    notification.notify(success_messages[action],1);
                } else {
                    notification.notify(data.messages,0);
                }
            }).error(notification.server_error);
        }
    }

    var update_list_node = function(obj) {
        return $http.post('/orders/updateorderlist.json',obj).success(function(data){
            if(data.status) {
                notification.notify("Successfully Updated",1);
            } else {
                notification.notify(data.error_msg,0);
            }
        }).error(notification.server_error);
    }

    //single order related functions
    var get_single = function(id,orders) {
        return $http.get('/orders/getdetails/'+ id+'.json').success(function(data) {
            orders.single = {};
            if(data.order) {
                orders.single = data.order;
            }
        });
    }

    var update_single = function(orders,auto) {
        if(typeof auto !== "boolean") {
            auto = true;
        }
        var order_data = {};
        for(i in orders.single.basicinfo) {
            if(i != 'id' && i != 'created_at' && i!='updated_at') {
                order_data[i] = orders.single.basicinfo[i];
            }
        }
        return $http.post("orders/update.json",{id: orders.single.basicinfo.id , order: order_data}).success(
            function(data) {
                if(data.status) {
                    if(!auto) {
                        notification.notify("Successfully Updated",1);
                    }
                } else {
                    notification.notify(data.messages,0);
                }
            }
        ).error(notification.server_error);
    }
    var rollback_single = function(single) {
        update_single({single: single});
        return $http.post("orders/rollback.json",{single: single}).success(
            function(data) {
                if(data.status) {
                    notification.notify("Successfully Updated",1);
                } else {
                    notification.notify(data.messages,0);
                }
            }
        ).error(notification.server_error);
    }
    var single_add_item = function(orders,ids) {
        return $http.post("orders/additemtoorder.json",{productids: ids , id: orders.single.basicinfo.id, qty:1}).success(
            function(data) {
                if(data.status) {
                    notification.notify("Item Successfully Added",1);
                } else {
                    notification.notify("Error adding",0);
                }
            }
        ).error(notification.server_error);
    }

    var single_remove_item = function(ids) {
        return $http.post("orders/removeitemfromorder.json",{orderitem: ids}).success(
            function(data) {
                if(data.status) {
                    notification.notify("Item Successfully Removed",1);
                } else {
                    notification.notify("Error removing",0);
                }
            }
        ).error(notification.server_error);
    }

    var single_record_exception = function(orders) {
        return $http.post(
            '/orders/recordexception.json',
            {
                id: orders.single.basicinfo.id,
                reason: orders.single.exception.reason,
                description: orders.single.exception.description,
                assoc: orders.single.exception.assoc
            }
        ).success(function(data) {
                if(data.status) {
                    notification.notify("Exception successfully recorded",1);
                } else {
                    notification.notify(data.messages,0);
                }
        }).error(notification.server_error);
    }

    var single_clear_exception = function(orders) {
        return $http.post('/orders/clearexception.json', {id: orders.single.basicinfo.id}).success(function(data) {
            if(data.status) {
                notification.notify("Exception successfully cleared",1);
            } else {
                notification.notify(data.messages,0);
            }
        }).error(notification.server_error);
    }

     var single_update_item_qty = function(item) {
        return $http.post('/orders/updateiteminorder.json',{orderitem: item.id, qty: item.qty}).success(function(data) {
            if(data.status) {
                notification.notify("Item updated",1);
            } else {
                notification.notify(data.messages,0);
            }
        }).error(notification.server_error);
    }

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
            rollback:rollback_single,
            item: {
                add: single_add_item,
                remove: single_remove_item,
                update:  single_update_item_qty
            },
            exception: {
                record: single_record_exception,
                clear: single_clear_exception
            }
        }
    }
}]);
