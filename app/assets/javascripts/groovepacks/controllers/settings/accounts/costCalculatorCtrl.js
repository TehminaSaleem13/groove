groovepacks_controllers.
  controller('costCalculatorCtrl', ['$scope', '$http', '$timeout', '$location', '$state', '$cookies', '$modal', '$rootScope', 'notification', 'payments', 'groov_translator',
    function ($scope, $http, $timeout, $location, $state, $cookies, $modal, $rootScope, notification, payments, groov_translator) {

      var myscope = {};
      myscope.init = function () {
        $http.get('/settings/get_settings').success(function(response){
          $scope.setup_page('show_card_details', 'cost_calculator');
          $scope.cost_calculator_url = response.data.settings.cost_calculator_url
          $scope.cost = {}
          $scope.cost.total_cot_per_error = getUrlParameter("total_cost", response) 
          $scope.cost.error_cost_per_day = getUrlParameter("error_cost_per_day", response) 
          $scope.cost.monthly_shipping = getUrlParameter("monthly_shipping", response) 
          $scope.cost.gp_cost = getUrlParameter("gp_cost", response)
          $scope.cost.monthly_saving = getUrlParameter("monthly_saving", response)
        })
      };

      var getUrlParameter = function getUrlParameter(sParam, response) {
        var sPageURL = decodeURIComponent(response.data.settings.cost_calculator_url),
            sURLVariables = sPageURL.split('&'),
            sParameterName,
            i;
        for (i = 0; i < sURLVariables.length; i++) {
          sParameterName = sURLVariables[i].split('=');
          if (sParameterName[0] === sParam) {
              return sParameterName[1] === undefined ? true : sParameterName[1];
          }
        }
      };
    
      myscope.init();
    }]);
