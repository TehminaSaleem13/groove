groovepacks_directives.directive('groovDragtable',['$timeout', function ($timeout) {

    return {
        scope: {
            model: '=groovModel',
            options:'=groovDragtable'
        },
        link:function(scope,el,attrs) {

            var myscope = {};

            myscope.persist = function(table) {
                var start = table.startIndex -1;
                var end = table.endIndex -1;
                scope.$apply(function() {
                    if(table.startIndex != table.endIndex) {
                        scope.model.splice(end,0,scope.model.splice(start,1)[0]);
                        if(typeof scope.options.update == 'function') {
                            scope.options.update();
                        }
                    }
                });

            };
            myscope.prefunc = function(cell) {
                if(cell.attributes['groov-draggable'].value == 'true') {
                    el.addClass("draginit");
                } else {
                    return false;
                }
            };

            myscope.prepersist = function (cell) {
                el.removeClass("draginit");
            };

            myscope.reload = function() {
                if(scope.options.reload) {
                    $timeout(function () {
                        if (scope.options.enabled) {
                            if(el.data('akottr-dragtable')) {
                                el.dragtable("redraw");
                            } else {
                                el.dragtable({
                                    persistState: myscope.persist,
                                    clickDelay: 200,
                                    beforeStart: myscope.prefunc,
                                    beforeStop: myscope.prepersist,
                                    maxMovingRows: 50,
                                    doRealSort: false
                                });
                            }
                            scope.options.reload = false;
                        }
                    });
                }
            };

            scope.$watch('options.reload',myscope.reload);
        }
    }
}]);
