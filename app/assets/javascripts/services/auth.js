groovepacks_services.factory("auth", ['$http','$rootScope',function($http,$rootScope) {
    var current_user = {};
    var check = function () {
        return $http.get('/home/userinfo.json',{ignoreLoadingBar: true}).success(function(data){
            current_user = data;
            $rootScope.$broadcast("user-data-reloaded");
        });
    };


    var get_current = function () {
        return current_user;
    };

    var home = function () {
        //check if access to orders
        if(has_access('orders')) {
            return 'orders';
        }
        return 'scanpack.rfo';
    };

    var prevent = function (name) {
        var to = false;
        var params = {};
        if(name == "home" || !has_access(name)) {
            to = home();
        }
        if (to == name) {
            to = false;
        }

        return {to: to, params: params};
    };

    //Should always mimic code from app/model/user.rb User::can?
    var user_can = function (setting) {
        if(typeof current_user['role'] == 'undefined') return false;
        if (current_user.role.make_super_admin) return true;

        if( ['create_edit_notes','change_order_status','import_orders'].indexOf(setting) != -1 ) {
            return (current_user.role.add_edit_order_items || current_user.role[setting]);
        }

        if(typeof current_user.role[setting] == "boolean") {
            return current_user.role[setting];
        }
        return false;
    };

    var has_access = function (name) {
        if(name == "home") return true;

        if(name.indexOf('.') != -1) {
            name = name.substr(0, name.indexOf('.'))
        }
        return user_can('access_' + name);
    };

    return {
        check: check,
        get: get_current,
        prevent: prevent,
        can: user_can,
        access: has_access
    };

}]);
