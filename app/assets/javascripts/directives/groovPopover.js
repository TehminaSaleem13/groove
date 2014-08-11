groovepacks_directives.directive( 'groovPopoverPopup', [ '$rootElement','$sce', function ( $rootElement,$sce ) {
    return {
        restrict: 'EA',
        replace: true,
        scope: { title: '@', content: '@', placement: '@', animation: '&', isOpen: '&' },
        template: "<div class=\"popover {{placement}}\" ng-class=\"{ in: isOpen(), fade: animation() }\">\n" +
            "  <div class=\"arrow\"></div>\n" +
            "\n" +
            "  <div class=\"popover-inner\">\n" +
            "      <h3 class=\"popover-title\" ng-bind-html=\"htmlTitle\" ng-show=\"title\"></h3>\n" +
            "      <div class=\"popover-content\" ng-bind-html=\"htmlContent\"></div>\n" +
            "  </div>\n" +
            "</div>\n" +
            "",
        link: function(scope, element) {
            scope.$watch('content', function(value) {
                scope.htmlContent = $sce.trustAsHtml(value);
            });
            scope.$watch('title', function(value) {
                scope.htmlTitle = $sce.trustAsHtml(value);
            });

        }
    };
}])
.directive( 'groovPopover', [ '$tooltip', function ( $tooltip ) {
    return $tooltip( 'groovPopover', 'popover', 'mouseenter' );
}]);
