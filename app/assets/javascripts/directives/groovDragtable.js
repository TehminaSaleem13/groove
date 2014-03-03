groovepacks_directives.directive('groovDragtable',['$timeout', function ($timeout) {

    return {
        scope: {
            model: '=groovModel',
            update:'=groovDragtable'
        },
        link:function(scope,el,attrs) {

            var persist = function(table) {
                var start = table.startIndex -1;
                var end = table.endIndex -1;
                scope.$apply(function() {
                    if(table.startIndex != table.endIndex) {
                        scope.model.splice(end,0,scope.model.splice(start,1)[0]);
                        if(typeof scope.update == 'function') {
                            scope.update();
                        }
                    }
                    el.removeClass("draginit");
                })

            }
            var prefunc = function() {
                el.addClass("draginit");
            }
            $timeout(function() {el.dragtable({persistState:persist,clickDelay:100, beforeStart: prefunc, maxMovingRows:50,doRealSort:false});});
        }
    }
}]);
