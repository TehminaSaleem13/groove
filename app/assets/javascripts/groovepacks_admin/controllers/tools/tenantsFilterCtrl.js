groovepacks_controllers.controller('tenantsFilterCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location',
  '$state', '$cookies', 'tenants',
  function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, tenants) {
//Definitions

    var myscope = {};
    /*
     * Public methods
     */


    myscope.init = function () {
      $scope.setup_child($stateParams);
    };

    myscope.init();
  }]);
