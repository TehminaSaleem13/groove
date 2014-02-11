groovepacks_directives.directive('compileTemplate', ['$compile','$parse',function($compile, $parse){
    return {
        link: function(scope, element, attr){
            var parsed = $parse(attr.ngBindHtml);
            var getStringValue = function () { return (parsed(scope) || '').toString(); }
            //Recompile if the template changes
            scope.$watch(getStringValue, function() {
                $compile(element, null, -9999)(scope);  //The -9999 makes it skip directives so that we do not recompile ourselves
            });
        }
    }
}]);
