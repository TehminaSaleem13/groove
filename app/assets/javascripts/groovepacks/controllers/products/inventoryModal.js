groovepacks_controllers.controller('inventoryModal', [ '$scope', 'hotkeys', '$state', '$stateParams', '$modalInstance', '$timeout','warehouses','inventory_manager','products',
function($scope, hotkeys, $state,$stateParams,$modalInstance,$timeout,warehouses,inventory_manager,products) {
    var myscope = {};


    /**
     * Public methods
     */

    $scope.ok = function() {
        $modalInstance.close("ok-button-click");
    };
    $scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
    };

    $scope.update = function(reason) {
        if(reason == "cancel-button-click") {

        } else {
        }
    };

    $scope.submit_recount_or_receive_inventory = function() {
    };

    $scope._handle_inv_manager_key_event = function(event) {
        if(event.which == 13) {
            //call products service
            $scope.products_inv_manager = products.model.get();
            products.single.get_by_barcode($scope.inventory_manager.single.product_barcode,
                $scope.products_inv_manager).then(function(){
                    console.log($scope.products_inv_manager);
                    $scope._inventory_count_inputObj = $('input#inventory_count');
                    $scope.inventory_manager.single.id = $scope.products_inv_manager.single.basicinfo.id;
                    $scope.inventory_manager.single.inventory_count = '';
                    $scope.inventory_manager.single.location_primary = '';
                    $scope.inventory_manager.single.location_secondary = '';
                    $scope.inventory_manager.single.location_tertiary = '';
                    $scope.check_if_inv_wh_is_associated_with_product();
                    $timeout(function() {$scope._inventory_count_inputObj.focus()},20);
                });
            //console.log($scope.inventory_manager.single.product_barcode);
        }
    };

    $scope.check_if_inv_wh_is_associated_with_product = function() {
        $scope.inv_wh_found = false;
        if (typeof $scope.products_inv_manager.single.inventory_warehouses != 'undefined'){
            for (var i = 0; i < $scope.products_inv_manager.single.inventory_warehouses.length; i++) {
                if ($scope.products_inv_manager.single.inventory_warehouses[i].warehouse_info.id ==
                    $scope.inventory_manager.single.inv_wh_id) {
                    $scope.inv_wh_found = true;
                }
            }
        }
    };

    $scope._handle_inv_count_key_event = function(event) {
        if(event.which === 13) {
            //call inventory manager service
            inventory_manager.single.update($scope.inventory_manager).then(function(){
                products.single.reset_obj($scope.products_inv_manager);
                $scope.inventory_manager.single.product_barcode = '';
                $scope.inventory_manager.single.inventory_count = '';
                $scope.inventory_manager.single.location_primary = '';
                $scope.inventory_manager.single.location_secondary = '';
                $scope.inventory_manager.single.location_tertiary = '';
                $timeout(function() {$scope._inventory_warehouse_inputObj.focus()},20);
            });
            event.preventDefault();
        }
    };

    $scope.handle_change_event = function(id) {
        if(typeof id != "undefined" && id) {
            $scope.inventory_manager.single.inv_wh_id = id;
        }
        $scope.check_if_inv_wh_is_associated_with_product();
        $timeout(function() {$scope._inventory_warehouse_inputObj.focus()},20);
    };

    myscope.init = function() {
        //alert('Recounting or receiving inventory');
        $scope.warehouses = warehouses.model.get();
        $scope.inventory_manager = inventory_manager.model.get();
        $scope.products_inv_manager = products.model.get();
        warehouses.list.get($scope.warehouses).then(function() {
            //register events for recount and receive inventory
            $scope._inventory_warehouse_inputObj = $('input#inventorymanagerbarcode');
            if(typeof $scope.inventory_manager.single['inv_wh_id'] != "number") {
                for(var i=0; i < $scope.warehouses.list.length; i++) {
                    if ($scope.warehouses.list[i].info.is_default) {
                        $scope.inventory_manager.single.inv_wh_id = $scope.warehouses.list[i].info.id;
                        break;
                    }
                }
            }
            //$('#showProductInv').modal('show');
            $timeout(function() {$scope._inventory_warehouse_inputObj.focus()},20);
        });
        $modalInstance.result.then($scope.update,$scope.update);
    };
    myscope.init();

}]);
