groovepacks_admin_directives.directive('groovClick', ['$parse', '$timeout', function ($parse, $timeout) {
  return {
    restrict: "A",
    link: function (scope, element, attrs) {
      var fn = $parse(attrs.groovClick);
      element.bind('click', function (event) {
        scope.$apply(function () {
          event.preventDefault();
          event.stopPropagation();
          $timeout(function () {
            fn(scope, {$event: event});
          }, 200);
        });
      });
    }
  };
}]);
