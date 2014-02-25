angular.module('groovepacks', ['groovepacks.filters', 'groovepacks.services', 'groovepacks.directives', 'groovepacks.controllers','ui.sortable','pasvaz.bindonce', 'ngCookies', 'ngRoute','ngAnimate']).
  config(['$routeProvider', function($routeProvider) {
    $routeProvider.when('/orders',
    	{templateUrl: '/assets/partials/showorders.html', controller: 'showOrdersCtrl'});
    $routeProvider.when('/settings',
    	{templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'});
    $routeProvider.when('/settings/showusers',
    	{templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'});
    $routeProvider.when('/settings/showusers/:action',
        {templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'});
    $routeProvider.when('/settings/showstores',
        {templateUrl: '/assets/partials/showstores.html', controller: 'showStoresCtrl'});
    $routeProvider.when('/settings/showstores/:action',
            {templateUrl: '/assets/partials/showstores.html', controller: 'showStoresCtrl'});
    $routeProvider.when('/products',
    	{templateUrl: '/assets/partials/showproducts.html', controller: 'showProductsCtrl'});
    $routeProvider.when('/scanandpack',
        {templateUrl: '/assets/partials/showscanandpack.html', controller: 'showScanPackCtrl'});
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

String.prototype.chunk = function(size) {
    return [].concat.apply([],
        this.split('').map(function(x,i){
            return i%size ? [] : this.slice(i,i+size)
        }, this)
    )
}

String.prototype.trimmer = function (chr) {
    return this.replace((!chr) ? new RegExp('^\\s+|\\s+$', 'g') : new RegExp('^'+chr+'+|'+chr+'+$', 'g'), '');
}
