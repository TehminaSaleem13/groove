groovepacks_services.factory("auth", ['$http', '$rootScope', 'groovIO', function ($http, $rootScope, groovIO) {
  var current_user = {};
  var check = function () {
    return $http.get('/home/userinfo.json', {ignoreLoadingBar: true}).success(function (data) {
      if (!jQuery.isEmptyObject(data)) {
        groovIO.connect();
      } else {
        groovIO.disconnect();
      }
      current_user = data;
      $rootScope.$broadcast("user-data-reloaded");
    });
  };


  var get_current = function () {
    return current_user;
  };

  var home = function () {
    //check if access to orders
    if (has_access('orders')) {
      return 'orders';
    }
    return 'scanpack.rfo';
  };

  var prevent = function (name) {
    var to = false;
    var params = {};
    if (name == "home" || !has_access(name)) {
      to = home();
    }
    if (to == name) {
      to = false;
    }

    return {to: to, params: params};
  };

  var user_can = function (setting) {
    return public_user_can(current_user, setting);
  };

  //Should always mimic code from app/model/user.rb User::can?
  var public_user_can = function (user, setting) {
    if (typeof user['role'] == 'undefined') return false;
    if (user.role.make_super_admin) return true;

    if (['create_edit_notes', 'change_order_status', 'import_orders'].indexOf(setting) != -1) {
      return (user.role.add_edit_order_items || user.role[setting]);
    }

    if (typeof user.role[setting] == "boolean") {
      return user.role[setting];
    }
    return false;
  };

  var has_access = function (name) {
    if (name == "home") return true;

    if (name.indexOf('.') != -1) {
      name = name.substr(0, name.indexOf('.'))
    }
    return user_can('access_' + name);
  };

  return {
    check: check,
    get: get_current,
    prevent: prevent,
    can: user_can,
    user_can: public_user_can,
    access: has_access
  };

}]);
