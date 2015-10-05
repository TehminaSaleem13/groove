groovepacks_controllers.
  controller('appCtrl', ['$rootScope', '$scope', '$timeout', '$modalStack', '$state', '$filter', '$document', '$window', 'hotkeys', 'auth', 'notification', 'importOrders', 'groovIO', 'editable', 'stores',
    function ($rootScope, $scope, $timeout, $modalStack, $state, $filter, $document, $window, hotkeys, auth, notification, importOrders, groovIO, editable, stores) {

      $scope.$on("user-data-reloaded", function () {
        $scope.current_user = auth;
      });

      $scope.show_logout_box = false;
      groovIO.on('ask_logout', function (msg) {
        if (!$scope.show_logout_box) {
          notification.notify(msg.message);
          $scope.show_logout_box = true;
        }
      });

      groovIO.on('hide_logout', function (msg) {
        if ($scope.show_logout_box) {
          notification.notify(msg.message, 1);
          $scope.show_logout_box = false;
        }
      });

      $rootScope.$on("editing-a-var", function (event, data) {
        $scope.currently_editing = (data.ident !== false);
      });

      $scope.log_out = function (who) {
        if (who === 'me') {
          groovIO.log_out({message: ''});
        } else if (who === 'everyone_else') {
          groovIO.emit('logout_everyone_else');
        }
      };
      $scope.stop_editing = function () {
        editable.force_exit();
      };

      $scope.is_active_tab = function (string) {
        var name = $state.current.name;
        if (name.indexOf('.') != -1) {
          name = name.substr(0, name.indexOf('.'))
        }
        return (string == name);
      };
      $scope.notify = function (msg, type) {
        notification.notify(msg, type);
      };
      var myscope = {};

      $rootScope.focus_search = function (event) {
        var elem;
        if (typeof event != 'undefined') {
          event.preventDefault();
        }
        //if cheatsheet is open, do nothing;
        if ($document.find('.cfp-hotkeys-container').hasClass('in')) {
          return;
        }
        // If in modal
        if ($document.find('body').hasClass('modal-open')) {
          elem = $document.find('.modal-dialog:last .modal-body .search-box');
        } else {
          elem = $document.find('.search-box');
        }
        elem.focus();
        return elem;
      };
      hotkeys.bindTo($scope).add({
        combo: ['return'],
        description: 'Focus search/scan bar (if present)',
        callback: $rootScope.focus_search
      });
      hotkeys.bindTo($scope).add({
        combo: ['mod+shift+e'],
        description: 'Exit Editing mode',
        callback: $scope.stop_editing
      });

      document.onmouseover = function () {
        if (!$scope.mouse_in_page) {
          $scope.$apply(function () {
            $scope.mouse_in_page = true;
          });
        }
      };
      document.onmouseleave = function () {
        if ($scope.mouse_in_page) {
          $scope.$apply(function () {
            $scope.mouse_in_page = false;
          });
        }
      };

      //myscope.get_status();
      $rootScope.$on('$stateChangeStart', function (event, toState, toParams, fromState, fromParams) {
        if ($(".modal").is(':visible') && toState.name != fromState.name) {
          var modal = $modalStack.getTop();
          if (modal && modal.value.backdrop && modal.value.backdrop != 'static' && !$scope.mouse_in_page) {
            event.preventDefault();
            $modalStack.dismiss(modal.key, 'browser-back-button');
          }
        }
      });
      $rootScope.$on('$viewContentLoaded', function () {
        $timeout($rootScope.focus_search);
      });
    }]);
