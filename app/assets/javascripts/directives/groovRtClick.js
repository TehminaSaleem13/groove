groovepacks_directives.directive('groovRtClick', ['$parse',function($parse) {
    return {
        restrict: "A",
        link: function(scope, element, attrs) {
            var fn = $parse(attrs.groovRtClick);
            element.bind('contextmenu', function(event) {
                scope.$apply(function() {
                    event.preventDefault();
                    event.stopPropagation();
                    fn(scope, {$event:event});
                });
            });
        }
    };
}]);
