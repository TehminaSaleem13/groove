groovepacks_admin_directives.provider('$groovTooltip', function () {
// The default options tooltip and popover.
  var defaultOptions = {
    placement: 'top',
    animation: true,
    popupDelay: 0
  };

// Default hide triggers for each show trigger
  var triggerMap = {
    'mouseenter': 'mouseleave',
    'click': 'click',
    'focus': 'blur'
  };

// The options specified to the provider globally.
  var globalOptions = {};

  this.options = function (value) {
    angular.extend(globalOptions, value);
  };


  this.setTriggers = function setTriggers(triggers) {
    angular.extend(triggerMap, triggers);
  };


  function snake_case(name) {
    var regexp = /[A-Z]/g;
    var separator = '-';
    return name.replace(regexp, function (letter, pos) {
      return (pos ? separator : '') + letter.toLowerCase();
    });
  }

  /**
   * Returns the actual instance of the $tooltip service.
   * TODO support multiple triggers
   */
  this.$get = ['$window', '$compile', '$timeout', '$parse', '$document', '$position', '$interpolate', function ($window, $compile, $timeout, $parse, $document, $position, $interpolate) {
    return function $tooltip(type, prefix, defaultTriggerShow, override) {
      var options = angular.extend({}, defaultOptions, globalOptions);
      if (typeof override === 'undefined') {
        override = false;
      }

      /**
       * Returns an object of show and hide triggers.
       *
       * If a trigger is supplied,
       * it is used to show the tooltip; otherwise, it will use the `trigger`
       * option passed to the `$tooltipProvider.options` method; else it will
       * default to the trigger supplied to this directive factory.
       *
       * The hide trigger is based on the show trigger. If the `trigger` option
       * was passed to the `$tooltipProvider.options` method, it will use the
       * mapped trigger from `triggerMap` or the passed trigger if the map is
       * undefined; otherwise, it uses the `triggerMap` value of the show
       * trigger; else it will just use the show trigger.
       */
      function getTriggers(trigger) {
        var show = trigger || options.trigger || defaultTriggerShow;
        var hide = triggerMap[show] || show;
        return {
          show: show,
          hide: hide
        };
      }

      var directiveName = snake_case(type);

      var startSym = $interpolate.startSymbol();
      var endSym = $interpolate.endSymbol();
      var template =
        '<div ' + directiveName + '-popup ' +
        'title="' + startSym + 'tt_title' + endSym + '" ' +
        'content="' + startSym + 'tt_content' + endSym + '" ' +
        'placement="' + startSym + 'tt_placement' + endSym + '" ' +
        'animation="tt_animation" ' +
        'is-open="tt_isOpen" ' +
        '>' +
        '</div>';

      return {
        restrict: 'EA',
        scope: true,
        compile: function (tElem, tAttrs) {
          var tooltipLinker = $compile(template);

          return function link(scope, element, attrs) {
            var tooltip;
            var transitionTimeout;
            var popupTimeout;
            var appendToBody = angular.isDefined(options.appendToBody) ? options.appendToBody : false;
            var triggers = getTriggers(undefined);
            var hasEnableExp = angular.isDefined(attrs[prefix + 'Enable']);

            var positionTooltip = function () {

              var ttPosition = $position.positionElements(element, tooltip, scope.tt_placement, appendToBody);
              ttPosition.top += 'px';
              ttPosition.left += 'px';

              // Now set the calculated positioning.
              tooltip.css(ttPosition);
            };

            // By default, the tooltip is not open.
            // TODO add ability to start tooltip opened
            scope.tt_isOpen = false;
            if (override) {
              scope.tt_show = show;
              scope.tt_timeout = null;
              scope.tt_hide = hide;
            }

            function toggleTooltipBind() {
              if (!scope.tt_isOpen) {
                showTooltipBind();
              } else {
                hideTooltipBind();
              }
            }

            // Show the tooltip with delay if specified, otherwise show it immediately
            function showTooltipBind() {
              if (hasEnableExp && !scope.$eval(attrs[prefix + 'Enable'])) {
                return;
              }
              if (scope.tt_popupDelay) {
                // Do nothing if the tooltip was already scheduled to pop-up.
                // This happens if show is triggered multiple times before any hide is triggered.
                if (!popupTimeout) {
                  popupTimeout = $timeout(show, scope.tt_popupDelay, false);
                  popupTimeout.then(function (reposition) {
                    reposition();
                  });
                }
              } else {
                show()();
              }
            }

            function hideTooltipBind() {
              if (override) {
                scope.tt_timeout = $timeout(function () {
                  scope.tt_hide();
                }, 500);
              } else {
                scope.$apply(function () {
                  hide();
                });
              }

            }

            // Show the tooltip popup element.
            function show() {

              popupTimeout = null;

              // If there is a pending remove transition, we must cancel it, lest the
              // tooltip be mysteriously removed.
              if (transitionTimeout) {
                $timeout.cancel(transitionTimeout);
                transitionTimeout = null;
              }
              if (scope.tt_timeout) {
                $timeout.cancel(scope.tt_timeout);
                scope.tt_timeout = null;
              }

              // Don't show empty tooltips.
              if (!scope.tt_content) {
                return angular.noop;
              }

              createTooltip();

              // Set the initial positioning.
              tooltip.css({top: 0, left: 0, display: 'block'});

              // Now we add it to the DOM because need some info about it. But it's not
              // visible yet anyway.
              if (appendToBody) {
                $document.find('body').append(tooltip);
              } else {
                element.after(tooltip);
              }

              positionTooltip();

              // And show the tooltip.
              scope.tt_isOpen = true;
              scope.$digest(); // digest required as $apply is not called

              // Return positioning function as promise callback for correct
              // positioning after draw.
              return positionTooltip;
            }

            // Hide the tooltip popup element.
            function hide() {
              // First things first: we don't show it anymore.
              scope.tt_isOpen = false;

              //if tooltip is going to be shown after delay, we must cancel this
              $timeout.cancel(popupTimeout);
              popupTimeout = null;

              // And now we remove it from the DOM. However, if we have animation, we
              // need to wait for it to expire beforehand.
              // FIXME: this is a placeholder for a port of the transitions library.
              if (scope.tt_animation) {
                if (!transitionTimeout) {
                  transitionTimeout = $timeout(removeTooltip, 800);
                }
              } else {
                removeTooltip();
              }
            }

            function createTooltip() {
              // There can only be one tooltip element per directive shown at once.
              if (tooltip) {
                removeTooltip();
              }
              tooltip = tooltipLinker(scope, function () {
              });

              // Get contents rendered into the tooltip
              scope.$digest();
            }

            function removeTooltip() {
              transitionTimeout = null;
              if (tooltip) {
                tooltip.remove();
                tooltip = null;
              }
            }

            /**
             * Observe the relevant attributes.
             */
            attrs.$observe(type, function (val) {
              scope.tt_content = val;

              if (!val && scope.tt_isOpen) {
                hide();
              }
            });

            attrs.$observe(prefix + 'Title', function (val) {
              scope.tt_title = val;
            });

            attrs.$observe(prefix + 'Placement', function (val) {
              scope.tt_placement = angular.isDefined(val) ? val : options.placement;
            });

            attrs.$observe(prefix + 'PopupDelay', function (val) {
              var delay = parseInt(val, 10);
              scope.tt_popupDelay = !isNaN(delay) ? delay : options.popupDelay;
            });

            attrs.$observe('ngModel', function (val) {
              scope.tt_model = val;
            });

            var unregisterTriggers = function () {
              element.unbind(triggers.show, showTooltipBind);
              element.unbind(triggers.hide, hideTooltipBind);
            };

            attrs.$observe(prefix + 'Trigger', function (val) {
              unregisterTriggers();

              triggers = getTriggers(val);

              if (triggers.show === triggers.hide) {
                element.bind(triggers.show, toggleTooltipBind);
              } else {
                element.bind(triggers.show, showTooltipBind);
                element.bind(triggers.hide, hideTooltipBind);
              }
            });

            var animation = scope.$eval(attrs[prefix + 'Animation']);
            scope.tt_animation = angular.isDefined(animation) ? !!animation : options.animation;

            attrs.$observe(prefix + 'AppendToBody', function (val) {
              appendToBody = angular.isDefined(val) ? $parse(val)(scope) : appendToBody;
            });

            // if a tooltip is attached to <body> we need to remove it on
            // location change as its parent scope will probably not be destroyed
            // by the change.
            if (appendToBody) {
              scope.$on('$locationChangeSuccess', function closeTooltipOnLocationChangeSuccess() {
                if (scope.tt_isOpen) {
                  hide();
                }
              });
            }

            // Make sure tooltip is destroyed and removed.
            scope.$on('$destroy', function onDestroyTooltip() {
              $timeout.cancel(transitionTimeout);
              $timeout.cancel(popupTimeout);
              unregisterTriggers();
              removeTooltip();
            });
          };
        }
      };
    };
  }];
}).directive('groovPopoverPopup', ['$rootElement', '$sce', '$timeout', function ($rootElement, $sce, $timeout) {
  return {
    restrict: 'EA',
    replace: true,
    scope: false,
    template: "<div class=\"popover {{tt_placement}}\" ng-mouseenter=\"cancel_timeout()\" ng-mouseleave=\"tt_hide()\"  ng-class=\"{ in: tt_isOpen, fade: tt_animation }\">\n" +
    "  <div class=\"arrow\"></div>\n" +
    "\n" +
    "  <div class=\"popover-inner\">\n" +
    "      <h3 class=\"popover-title\" ng-bind-html=\"htmlTitle\" ng-show=\"tt_title\"></h3>\n" +
    "      <div class=\"popover-content\" ng-bind-html=\"htmlContent\" compile-template></div>\n" +
    "  </div>\n" +
    "</div>\n" +
    "",
    link: function (scope, element) {
      var myscope = {};
      scope.cancel_timeout = function () {
        $timeout.cancel(scope.tt_timeout);
        scope.tt_timeout = null;
      };

      myscope.init = function () {
        myscope.timeout = null;
        scope.$watch('tt_content', function (value) {
          scope.htmlContent = $sce.trustAsHtml(value);
        });
        scope.$watch('tt_title', function (value) {
          scope.htmlTitle = $sce.trustAsHtml(value);
        });
      };
      myscope.init();

    }
  };
}])
  .directive('groovPopover', ['$groovTooltip', function ($tooltip) {
    return $tooltip('groovPopover', 'popover', 'mouseenter', true);
  }]);
