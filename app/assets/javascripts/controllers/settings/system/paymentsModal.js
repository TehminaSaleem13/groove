groovepacks_controllers.controller('paymentsModal',['$scope','$timeout',
	'$modalInstance','$q','notification','payments','$rootScope',
 function(scope,$timeout,$modalInstance, $q, notification, payments,$rootScope) {
 	var myscope = {};
 	myscope.init = function() {    
    scope.payments = payments.model.get();
    // scope.payments.single.
    console.log("payments");
    console.log(payments);
  };
 	scope.ok = function() {
    $modalInstance.close("ok-button-click");
  };
  scope.cancel = function () {
    $modalInstance.dismiss("cancel-button-click");
  };
  scope.addThisCard = function() {
  	console.log("addThisCard");
  	console.log(scope.payments.single);
  	payments.single.create(scope.payments.single).then(function(response) {
  		console.log("response");
  		console.log(response);
  		if(response.data.status == false) {
  			response.data.messages.forEach(function(message) {
  				notification.notify(message);
  			});
  		}
  		else {
  			scope.ok();
  			notification.notify("Added Your Card Successfully",1);
	  		$rootScope.$broadcast("myEvent");
  		}
  	});
  }
  myscope.init();
}]);