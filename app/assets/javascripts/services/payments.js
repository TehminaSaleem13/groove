groovepacks_services.factory('generalsettings',['$http','notification',function($http, notification) {
	
  var get_card_list = function(payments) {
    var url = '/payments/get_card_list.json';

    return $http.put(url, payments.list).success(
      # function(data) {
      #   if(data.status) {
      #     get_settings(settings);
      #     notification.notify(data.success_messages,1);
      #   } else {
      #       notification.notify(data.error_messages,0);
      #   }
      # }
    ).error(notification.server_error);
	};

	return {
    model: {
        get:get_default
    },
    list: {
    	get:get_card_list
    }
  };
}]);