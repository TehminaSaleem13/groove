groovepacks_controllers. 
controller('paymentsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', 'payments', 'groov_translator',
function( $scope, $http, $timeout, $location, $state, $cookies, payments, groov_translator) {

    var myscope = {};

    myscope.init = function() {
        $scope.setup_page('system','payment_details');
        $scope.translations = {
            "headings": {
                "credit_cards": ""
            },
            "labels": {
                "all_cards": ""
            },
            "tooltips": {
                
            }
        };
        groov_translator.translate('settings.system.general',$scope.translations);

        $scope.show_button = false;
        $scope.payments = payments.model.get();
        // console.log($scope.payments);
        payments.list.get($scope.payments);
        // console.log($scope.payments.list);
    };

    // $scope.get_card_list = function() {
    //     payments.list.get($scope.payments);
    // }

	myscope.init();
}]);
