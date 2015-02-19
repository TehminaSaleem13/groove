groovepacks_services.factory('payments',['$http','notification',function($http, notification) {
	var get_default = function() {
    return {
      list: [],
      single: {
      }
    };
  };
  var get_card_list = function(payments) {
    var url = '/payments';
    return $http.get(url).success(
      function(data) {
      	if(data.status == true) {
      		if (data.cards.data.length > 0) {
	        	return payments.list = data.cards.data;
	        } else {
            return payments.list = [];
	        	notification.notify("No cards found for the subscriber");
	        }
      	}
      	else {
      		data.messages.forEach(function(message) {
            notification.notify(message);
          });
      	}
        
      }
    ).error(notification.server_error);
  }

  var get_default_card = function(payments) {
  	var url = '/payments/default_card';
  	return $http.get(url).success(
  		function(response) {
  			if(response.status == true)
  				payments.single = response.default_card;
  			else {
  				response.messages.forEach(function(message) {
            notification.notify(message);
          });
  			}
  		}
  	).error(notification.server_error);
  }

  var create_card = function(payments) {
  	var url = '/payments';
  	return $http.post(url,payments).success(function(response) {
  		if(response.status == false) {
				response.messages.forEach(function(message) {
          notification.notify(message);
        });
			}
  	}).error(notification.server_error);
  }

  var delete_cards = function(cards) {
  	return $http.delete("payments/delete_cards",{params: {"id[]": cards}}).success(function(response) {
  		if(response.status == false) {
				response.messages.forEach(function(message) {
          notification.notify(message);
        });
			}
  	}).error(notification.server_error);
  }

  var make_card_default = function(card) {
  	return $http.get("payments/" + card.id + "/edit").success(function(response) {
  		if(response.status == false) {
				response.messages.forEach(function(message) {
          notification.notify(message);
        });
			}
  	}).error(notification.server_error);
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
    	create: create_card,
    	edit: make_card_default
    }
  };
}]);