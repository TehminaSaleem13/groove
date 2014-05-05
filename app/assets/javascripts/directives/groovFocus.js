groovepacks_directives.directive('groovFocus', function () {
    return {
        link: function (scope, el, attrs) {
            scope.$watch('current_state',function() {
                el.focus();
            })
        }
    };
});
