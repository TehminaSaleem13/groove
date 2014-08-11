groovepacks_directives.directive('groovDragtable',['$timeout', function ($timeout) {

    return {
        scope: {
            model: '=groovModel',
            options:'=groovDragtable'
        },
        link:function(scope,el,attrs) {

            var persist = function(table) {
                var start = table.startIndex -1;
                var end = table.endIndex -1;
                scope.$apply(function() {
                    if(table.startIndex != table.endIndex) {
                        scope.model.splice(end,0,scope.model.splice(start,1)[0]);
                        if(typeof scope.options.update == 'function') {
                            scope.options.update();
                        }
                    }
                })

            };
            var prefunc = function(cell) {
                if(cell.attributes['groov-draggable'].value == 'true') {
                    el.addClass("draginit");
                } else {
                    return false;
                }
            };

            var prePersist = function (cell) {
                el.removeClass("draginit");
            };

            $timeout(function() {
                if(scope.options.enabled) {
                    el.dragtable({persistState:persist,clickDelay:200, beforeStart: prefunc, beforeStop:prePersist, maxMovingRows:50,doRealSort:false});
                }
            });
        }
    }
}]);
