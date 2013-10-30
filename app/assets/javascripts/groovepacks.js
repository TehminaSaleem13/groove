angular.module('groovepacks', ['groovepacks.filters', 'groovepacks.services', 'groovepacks.directives', 'groovepacks.controllers','ui.sortable', 'ngCookies']).
  config(['$routeProvider', function($routeProvider) {
    $routeProvider.when('/orders', 
    	{templateUrl: '/assets/partials/showorders.html', controller: 'showOrdersCtrl'});

    $routeProvider.when('/settings', 
    	{templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'});
    $routeProvider.when('/settings/showusers', 
    	{templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'});
    $routeProvider.when('/settings/showstores', 
        {templateUrl: '/assets/partials/showstores.html', controller: 'showStoresCtrl'});
    $routeProvider.when('/products', 
    	{templateUrl: '/assets/partials/showproducts.html', controller: 'showProductsCtrl'});
    $routeProvider.when('/importorders', 
        {templateUrl: '/assets/partials/importorders.html', controller: 'importOrdersCtrl'});
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

groovepacks_directives.directive('fileUpload', function () {
    return {
        scope: true,
        link: function (scope, el, attrs) {
            el.bind('change', function (event) {
                var file = event.target.files[0];
                scope.$emit("fileSelected", { name: attrs.name, file: file });
            });
        }
    };
});
groovepacks_directives.directive('infiniteScroll', [
    '$rootScope', '$window', '$timeout', function($rootScope, $window, $timeout) {
        return {
            link: function(scope, elem, attrs) {
                var checkWhenEnabled, handler, scrollDistance, scrollEnabled;
                $window = angular.element($window);
                scrollDistance = 0;
                if (attrs.infiniteScrollDistance != null) {
                    scope.$watch(attrs.infiniteScrollDistance, function(value) {
                        return scrollDistance = parseInt(value, 10);
                    });
                }
                scrollEnabled = true;
                checkWhenEnabled = false;
                if (attrs.infiniteScrollDisabled != null) {
                    scope.$watch(attrs.infiniteScrollDisabled, function(value) {

                        scrollEnabled = !value;
                        if (scrollEnabled && checkWhenEnabled) {
                            checkWhenEnabled = false;
                            return handler();
                        }
                    });
                }
                handler = function() {
                    var elementBottom, remaining, shouldScroll, windowBottom;
                    windowBottom = $window.height() + $window.scrollTop();
                    elementBottom = elem.offset().top + elem.height();
                    remaining = elementBottom - windowBottom;
                    shouldScroll = remaining <= $window.height() * scrollDistance;
                    if (shouldScroll && scrollEnabled) {
                        if ($rootScope.$$phase) {
                            return scope.$eval(attrs.infiniteScroll);
                        } else {
                            return scope.$apply(attrs.infiniteScroll);
                        }
                    } else if (shouldScroll) {
                        return checkWhenEnabled = true;
                    }
                };
                $window.on('scroll', handler);
                scope.$on('$destroy', function() {
                    return $window.off('scroll', handler);
                });
                return $timeout((function() {
                    if (attrs.infiniteScrollImmediateCheck) {
                        if (scope.$eval(attrs.infiniteScrollImmediateCheck)) {
                            return handler();
                        }
                    } else {
                        return handler();
                    }
                }), 0);
            }
        };
    }
]);

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
