groovepacks_services.factory('payments',['$http','notification',function($http, notification) {
	var get_default = function() {
    return {
      list: [],
      single: {
      }
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

  var get_default_card = function(payments) {
  	var url = '/payments/default_card';
  	return $http.get(url).success(
  		function(response) {
  			payments.single = response;
  		}
  	).error(notification.server_error);
  }

  var create_card = function(payments) {
  	console.log("card_info");
  	console.log(payments);
  	var url = '/payments';
  	console.log(url);
  	$http.post(url,payments).success().error(notification.server_error);
  }

  var delete_cards = function(payments) {
  	paymens.forEach(function(payment) {
  		console.log(payment);
  	});
  }

	return {
    model: {
        get:get_default
    },
    list: {
    	get: get_card_list,
    	destroy: delete_cards
    },
    single: {
    	get: get_default_card,
    	create: create_card
    }
  };
}]);