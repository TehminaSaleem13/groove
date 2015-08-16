angular.module("logger", ["ui.bootstrap", "template/logger.html"]).factory(
  "logger", ['$timeout', '$rootScope', '$window', '$modal',
    function ($timeout, $rootScope, $window, $modal) {
      var open_log = function () {
        var log_modal = $modal.open({
          controller: 'LogModalCtrl',
          templateUrl: 'template/logger.html'
        });
        log_modal.result.then(function (data) {
          console.log("closed log");
        });
      }

      return {
        open: open_log
      };
    }]).controller("LogModalCtrl", ["$scope", function ($scope) {
    //todo
  }]);

angular.module("template/logger.html", []).run(["$templateCache",
  function ($templateCache) {
    $templateCache.put("template/logger.html",
      "<div>\n" +
      "<div class=\"modal-header\">\n" +
      "<button type=\"button\" class=\"close-btn\" ng-click=\"ok()\"><i class=\"glyphicon glyphicon-remove\"></i></button>\n" +
      "<div class=\"modal-title\">Log</div>\n" +
      "</div>\n" +
      "<div class=\"modal-body\">\n" +
      "<p style=\"text-center\">Welcome to Groovepacker Log</p>\n" +
      "</div>\n" +

      "<div class=\"modal-footer\">\n" +
      "<button ng-click=\"cancel()\" class=\"modal-cancel-button\" translate>modal.cancel</button>\n" +
      "</div>\n" +
      "</div>\n");
  }]);
