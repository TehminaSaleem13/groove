groovepacks_admin_controllers. 
controller('paymentsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', '$modal', '$rootScope', 'notification', 'payments', 'groov_translator',
function( $scope, $http, $timeout, $location, $state, $cookies, $modal, $rootScope, notification, payments, groov_translator) {

    var myscope = {};
    $scope.selectedPayments = [];
    myscope.init = function() {
        $scope.current_page = '';
        $scope.show_table_data = false;
        $scope.setup_page('show_card_details');
        $scope.translations = {
            "headings": {
                "credit_cards": ""
            },
            "labels": {
                "all_cards": ""
            }
        };
        groov_translator.translate('settings.accounts',$scope.translations);
        $scope.payments = payments.model.get();
        new $scope.getTableData();
    };
    $scope.getTableData = function() {
        payments.list.get($scope.payments).then(function(list) {
            if(typeof list.data.cards.data != 'undefined') {
                for(var i=0; i<list.data.cards.data.length; i++) {
                    list.data.cards.data[i].checked = false;
                }
            }
        });
        payments.single.get($scope.payments).then(function() {
            $scope.show_table_data = true;
        });
    }

    $scope.setSelected = function (idSelectedPayment) {
        var i;
        for(i=0; i<$scope.payments.list.length; i++) {
            if($scope.payments.list[i].id == idSelectedPayment) {
                $scope.payments.list[i].checked = !$scope.payments.list[i].checked;
            }
        }
    };

    $scope.openNewForm = function () {
        var cards_modal = $modal.open({
            controller: 'paymentsModal',
            templateUrl: '/assets/views/modals/settings/accounts/new_card.html' 
        });
        
    }

    $scope.deleteCard = function() {
        $scope.selectedPayments = [];
        $scope.payments.list.forEach(function(payment) {
            if(payment.checked)
                $scope.selectedPayments.push(payment.id);
        });
        if($scope.selectedPayments.length > 0) {
            payments.list.destroy($scope.selectedPayments).then(function() {
                $rootScope.$broadcast("myEvent");
            });
        }
        else
            notification.notify("Select one or more rows to remove");
    }

    $scope.setAsDefault = function() {
        $scope.selectedPayments = [];
        $scope.payments.list.forEach(function(payment) {
            if(payment.checked)
                $scope.selectedPayments.push(payment);
        });
        if($scope.selectedPayments.length == 1) {
            payments.single.edit($scope.selectedPayments[0]).then(function() {
                $rootScope.$broadcast("myEvent");
            });
        }
        else if($scope.selectedPayments.length > 1)
            notification.notify("Select only a single row to make it default");
        else
            notification.notify("Select a row to make it default");
    }

    $scope.$on("myEvent",function () {
        new $scope.getTableData();
    });

	myscope.init();
}]);
