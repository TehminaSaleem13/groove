groovepacks_admin_directives.directive('groovInclude', ['$http', '$templateCache', '$compile', function ($http, $templateCache, $compile) {
  return function (scope, element, attrs) {
    var templatePath = attrs.groovInclude;
    $http.get(templatePath, {cache: $templateCache}).success(function (response) {
      var contents = element.html(response).contents();
      $compile(contents)(scope);
    });
  };
}]);
