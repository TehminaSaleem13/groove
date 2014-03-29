groovepacks_services.factory("auth", ['$http','$rootScope',function($http,$rootScope) {
    var current_user = {};
    var check = function () {
        return $http.get('/home/userinfo.json').success(function(data){
            current_user = data;
            $rootScope.$broadcast("user-data-reloaded");
        });
    }


    var get_current = function () {
        return current_user;
    }

    var home = function () {
        //check if access to orders
        if(has_access('orders')) {
            return 'orders';
        }
        return 'scanpack';
    }

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
    }

    var has_access = function (name) {
        if(name == "home") return true;
        if(current_user['is_super_admin']) return true;

        if(name.indexOf('.') != -1) {
            name = name.substr(0, name.indexOf('.'))
        }
        var access = 'access_' + name;
        return current_user[access];

    }

    return {
        check: check,
        get: get_current,
        prevent: prevent,
        access: has_access
    };

}]);
