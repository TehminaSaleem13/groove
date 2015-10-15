groovepacks_directives.directive('infiniteScroll', [
  '$rootScope', '$window', '$timeout', function ($rootScope, $window, $timeout) {
    return {
      link: function (scope, elem, attrs) {
        var checkWhenEnabled, handler, scrollDistance, scrollEnabled, isWindow, scroller, ourElem;
        isWindow = (elem.css('overflow-y') == 'visible');
        $window = angular.element($window);
        scroller = isWindow ? $window : elem;


        scrollDistance = 0;
        if (attrs.infiniteScrollDistance != null) {
          scope.$watch(attrs.infiniteScrollDistance, function (value) {
            return scrollDistance = parseInt(value, 10);
          });
        }
        scrollEnabled = true;
        checkWhenEnabled = false;
        if (attrs.infiniteScrollDisabled != null) {
          scope.$watch(attrs.infiniteScrollDisabled, function (value) {
            scrollEnabled = !value;
            if (scrollEnabled && checkWhenEnabled) {
              checkWhenEnabled = false;
              return handler();
            }
          });
        }

        handler = function () {
          var elementBottom, remaining, shouldScroll, windowBottom;
          if (isWindow) {
            windowBottom = $window.height() + $window.scrollTop();
            elementBottom = elem.offset().top + elem.height();
          } else {
            windowBottom = elem.height() + elem.offset().top;
            ourElem = elem.find('.infinite-scroller');
            elementBottom = ourElem.offset().top + ourElem.height();
          }
          remaining = elementBottom - windowBottom;
          shouldScroll = remaining <= scroller.height() * scrollDistance;
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
        scroller.on('scroll', handler);
        scope.$on('$destroy', function () {
          return $window.off('scroll', handler);
        });
        return $timeout((function () {
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
