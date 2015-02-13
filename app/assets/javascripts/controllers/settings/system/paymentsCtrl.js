groovepacks_controllers. 
controller('paymentsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', '$modal', 'payments', 'groov_translator',
function( $scope, $http, $timeout, $location, $state, $cookies, $modal, payments, groov_translator) {

    var myscope = {};
    $scope.selectedPayments = [];
    myscope.init = function() {
        $scope.show_table_data = false;
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
        $scope.payments = payments.model.get();
        payments.list.get($scope.payments).then(function(list) {
            for(var i=0; i<list.length; i++) {
                list[i].checked = false;
            }
        });
        payments.single.get($scope.payments).then(function() {
            $scope.show_table_data = true;
        });
    };

    $scope.setSelected = function (idSelectedPayment) {
        var i;
        for(i=0; i<$scope.payments.list.length; i++) {
            if($scope.payments.list[i].id == idSelectedPayment) {
                $scope.payments.list[i].checked = !$scope.payments.list[i].checked;
            }
        }
    };

    $scope.openNewForm = function () {
        console.log("openNewForm");
        var alias_modal = $modal.open({
            controller: 'paymentsModal',
            templateUrl: '/assets/views/modals/settings/system/new_card.html'//,
        //     size:'lg',
        //     resolve: {
        //         // type: function(){return type},
        //         // exceptions: function(){return exceptions},
        //         // id: function(){return id;}
        //     }
        });
        // alias_modal.result.then(scope.add_item_order);
    }

    // $scope.get_card_list = function() {
    //     payments.list.get($scope.payments);
    // }

	myscope.init();
}]);
