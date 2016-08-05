groovepacks_controllers.
  controller('usersSingleCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$modal',
    '$modalStack', '$previousState', '$cookies',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $modal, $modalStack, $previousState, $cookies) {

      var myscope = {};
      /*
       * Public methods
       */


      myscope.init = function () {
        if (!$previousState.get("user-modal-previous") || $modalStack.getTop() == null) {
          //Show modal here
          myscope.user_obj = $modal.open({
            templateUrl: '/assets/views/modals/settings/user/main.html',
            controller: 'usersSingleModal',
            size: 'lg',
            resolve: {
              user_data: function () {
                return $scope.users
              }
            }
          });
          $previousState.forget("user-modal-previous");
          $previousState.memo("user-modal-previous");
          myscope.user_obj.result.finally(function () {
            $scope.select_all_toggle(false);
            $scope.user_modal_closed_callback();
            if ($previousState.get("user-modal-previous").state.name == "" ||
              $previousState.get("user-modal-previous").state.name.indexOf(
                'single', $previousState.get("user-modal-previous").state.name.length - 6) !== -1) {
              //If you landed directly on this URL, we assume that the last part of the state is the modal
              //So we remove that and send user on their way.
              // If there is no . in the string, we send user to home
              var toState = "home";
              var pos = $state.current.name.lastIndexOf(".");
              if (pos != -1) {
                toState = $state.current.name.slice(0, pos);
              }
              $previousState.forget("user-modal-previous");
              $timeout(function () {
                $state.go(toState, $stateParams);
              }, 700);
            } else {
              $timeout(function () {
                $previousState.go("user-modal-previous");
                $previousState.forget("user-modal-previous");
              }, 700);
            }
          });
        }

      };

      myscope.init();
    }]);
