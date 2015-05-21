groovepacks_admin_services.factory('groov_translator', ['$rootScope','$translate',function($rootScope,$translate) {

    var make_flat = function(base,object) {
        var list = [];
        var cur_base;
        for(var key in object) {
            if(!object.hasOwnProperty(key)) {
                continue;
            }
            cur_base = base+'.'+key;
            if(angular.isObject(object[key])) {
                list = list.concat(make_flat(cur_base,object[key]));
            } else {
                list.push(cur_base);
            }
        }
        return list;
    };



    var make_object = function(base, flat) {
        var obj = {};
        var cur_key;
        for(var key in flat) {
            cur_key = key;
            if(!flat.hasOwnProperty(key)|| key == flat[key]) {
                continue;
            }
            if(key.indexOf(base) === 0) {
                cur_key = key.substring(base.length+1);
            }
            cur_key.split('.').reduce(function(object, current,index, array){
                if(index == array.length -1) {
                    object[current] = flat[key];
                    return object;
                } else {
                    if(!angular.isObject(object[current])) {
                        object[current] = {};
                    }
                    return object[current];
                }
            },obj);
        }
        return obj;
    };

    var translate = function(base,object) {

        var flat_array = make_flat(base,object);

        $translate(flat_array).then(function(translations) {
            jQuery.extend(true,object,make_object(base,translations));

        });
        $rootScope.$on('$translateChangeSuccess', function () {
            $translate(flat_array).then(function(translations) {
                jQuery.extend(true,object,make_object(base,translations));
            });
        });
    };

    return {
        translate: translate
    }
}]);
