angular.module('groovepacks', ['groovepacks.filters', 'groovepacks.services', 'groovepacks.directives', 'groovepacks.controllers', 'ngCookies']).
  config(['$routeProvider', function($routeProvider) {
    $routeProvider.when('/orders', 
    	{templateUrl: '/assets/partials/orders.html', controller: 'ordersCtrl'});

    $routeProvider.when('/settings', 
    	{templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'});
    $routeProvider.when('/settings/showusers', 
    	{templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'});
    $routeProvider.when('/settings/showstores', 
        {templateUrl: '/assets/partials/showstores.html', controller: 'showStoresCtrl'});
    $routeProvider.when('/products', 
    	{templateUrl: '/assets/partials/showproducts.html', controller: 'showProductsCtrl'});
    $routeProvider.otherwise({redirectTo: '/settings/showstores'});
  }]).directive('xsInputSync', function() {
    return {
        restrict: "A",
        require: "?ngModel",
        link: function(scope, element, attrs, ngModel) {
            setInterval(function() {
                if (!(element.val()=='' && ngModel.$pristine))
                {
                    scope.$apply(function() {
                        ngModel.$setViewValue(element.val());
                    });
                }
                //console.log(scope);
            }, 100);
        }
    };
});

var groovepacks_controllers = angular.module('groovepacks.controllers', []);
var groovepacks_filters = angular.module('groovepacks.filters', []);
var groovepacks_services = angular.module('groovepacks.services', []);
var groovepacks_directives = angular.module('groovepacks.directives', []);