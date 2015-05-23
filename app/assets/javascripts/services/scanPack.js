groovepacks_services.factory('scanPack',['$http','notification','$state',function($http,notification,$state) {

    var get_state = function() {
        return {
            image:{
                enabled:false,
                time:0,
                src:''
            },
            sound: {
                enabled:false
            }
        }
    };

    var get_default = function() {
        return {
            state:'none',
            scan_states:{
                success:get_state(),
                fail:get_state(),
                order_complete:get_state()
            },
            settings: {}
        };
    };

    var input = function(input,state,id) {
        return $http.post('/scan_pack/scan_barcode.json',{input: input,state: state, id: id }).success(function(data) {
            notification.notify(data.notice_messages,2);
            notification.notify(data.success_messages,1);
            notification.notify(data.error_messages,0);
        }).error(notification.server_error);
    };

    var reset = function(id) {
       return $http.post('/scan_pack/reset_order_scan.json',{order_id: id}).success(function(data) {
            notification.notify(data.notice_messages,2);
            notification.notify(data.success_messages,1);
            notification.notify(data.error_messages,0);
            if(data.status) {
                if(typeof data.data != "undefined") {
                    if(typeof data.data.next_state != "undefined") {
                        //states[data.data.next_state](data.data);
                        if($state.current.name == data.data.next_state) {
                            $state.reload();
                        } else {
                            $state.go(data.data.next_state,data.data);
                        }
                    }
                }
            }
        }).error(notification.server_error);
    };

    var add_note =function (id,send_email,note) {
        return $http.post('/scan_pack/add_note.json',{id:id,email:send_email,note:note}).success(function(data){
            notification.notify(data.notice_messages,2);
            notification.notify(data.success_messages,1);
            notification.notify(data.error_messages,0);
        }).error(notification.server_error);
    };

    var get_settings = function(model) {
        return $http.get('/settings/get_scan_pack_settings.json').success(function(data) {
            if(data.status) {
                model.settings = data.settings;
            } else {
                notification.notify(data.error_messages,0);
            }
        }).error(notification.server_error);
    };

    var update_settings = function(model) {
        return $http.post('/settings/update_scan_pack_settings.json', model.settings).success(function(data) {
            if(data.status) {
                get_settings(model);
                notification.notify(data.success_messages,1);
            } else {
                notification.notify(data.error_messages,0);
            }
        }).error(notification.server_error);
    };
    
    var code_confirm = function(code) {
        return $http.post('/scan_pack/confirmation_code.json',{code: code}).success(function(data) {
        }).error(notification.server_error);
    };

    var order_instruction = function(id,code) {
        return code_confirm(code);
    };

    var type_scan = function(id,next_item,count) {
        return $http.post('/scan_pack/type_scan.json',{id: id, next_item: next_item, count: count}).success(function(data) {
            notification.notify(data.notice_messages,2);
            notification.notify(data.success_messages,1);
            notification.notify(data.error_messages,0);
        }).error(notification.server_error);
    };

    var product_instruction = function(id,next_item,code) {
        return $http.post('/scan_pack/product_instruction.json',{id: id, next_item: next_item, code: code}).success(function(data) {
            notification.notify(data.notice_messages,2);
            notification.notify(data.success_messages,1);
            notification.notify(data.error_messages,0);
        }).error(notification.server_error);
    };

    var click_scan = function(barcode,id) {
        return $http.post('/scan_pack/click_scan.json',{barcode:barcode,id:id}).success(function(data){
            notification.notify(data.notice_messages,2);
            notification.notify(data.success_messages,1);
            notification.notify(data.error_messages,0);
        }).error(notification.server_error);
    };

    var serial_scan = function(serial) {
        return $http.post('/scan_pack/serial_scan.json',serial).success(function(data) {
            notification.notify(data.notice_messages,2);
            notification.notify(data.success_messages,1);
            notification.notify(data.error_messages,0);
        }).error(notification.server_error);
    };

    return {

        input: input,
        reset:reset,
        settings: {
            model: get_default,
            get: get_settings,
            update: update_settings
        },
        add_note: add_note,
        states:{
            model:get_state
        },
        click_scan:click_scan,
        type_scan: type_scan,
        code_confirm: code_confirm,
        order_instruction: order_instruction,
        product_instruction: product_instruction,
        product_serial:serial_scan
    };
}]);
