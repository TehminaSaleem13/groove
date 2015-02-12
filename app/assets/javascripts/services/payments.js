groovepacks_services.factory('payments',['$http','notification',function($http, notification) {
	var get_default = function() {
    return {
      list: []
    };
  };
  var get_card_list = function(payments) {
    var url = '/payments/card_details';
    return $http.get(url).success(
      function(data) {
        if (data.data.length > 0) {
        	payments.list = data.data;
        	console.log(payments.list);
        } else {
        	notification.notify("No cards found for the subscriber");
        }
      }
    ).error(notification.server_error);
  }

	return {
    model: {
        get:get_default
    },
    list: {
    	get:get_card_list
    }
  };
}]);