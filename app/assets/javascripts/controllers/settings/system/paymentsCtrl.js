groovepacks_controllers. 
controller('paymentsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', '$modal', '$rootScope', 'notification', 'payments', 'groov_translator',
function( $scope, $http, $timeout, $location, $state, $cookies, $modal, $rootScope, notification, payments, groov_translator) {

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
        console.log("about to get list");
        new $scope.getTableData();
    };
    $scope.getTableData = function() {
        payments.list.get($scope.payments).then(function(list) {
            console.log("list: count:");
            console.log(list.data.data);
            for(var i=0; i<list.data.data.length; i++) {
                console.log("list :");
                console.log(list.data.data[i]);
                list.data.data[i].checked = false;
            }
        });
        payments.single.get($scope.payments).then(function() {
            console.log("found default card");
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
        console.log("openNewForm");
        var cards_modal = $modal.open({
            controller: 'paymentsModal',
            templateUrl: '/assets/views/modals/settings/system/new_card.html' 
        });
        
    }

    $scope.deleteCard = function() {
        console.log("list: ");
        console.log($scope.payments.list);
        $scope.payments.list.forEach(function(payment) {
            console.log("payment: ");
            console.log(payment);
            if(payment.checked)
                $scope.selectedPayments.push(payment);
        });
        payments.list.destroy($scope.selectedPayments);
        $rootScope.$broadcast("myEvent");
    }

    $scope.setAsDefault = function() {
        $scope.selectedPayments = [];
        $scope.payments.list.forEach(function(payment) {
            console.log("payment: ");
            console.log(payment);
            if(payment.checked)
                $scope.selectedPayments.push(payment);
        });
        if($scope.selectedPayments.length == 1) {
            payments.single.edit($scope.selectedPayments[0]).then(function() {
                $rootScope.$broadcast("myEvent");
            });
        }
        else if($scope.selectedPayments.length > 1) {
            console.log($scope.selectedPayments.length);
            $scope.selectedPayments.forEach(function(payment) {
                console.log(payment);
            });
            notification.notify("Select only a single row to make it default");
        }
        else
            notification.notify("Select a row to make it default");
    }

    $scope.$on("myEvent",function () {
        // myscope.init();
        new $scope.getTableData();
        console.log('my event occurred')
    });

	myscope.init();
}]);
