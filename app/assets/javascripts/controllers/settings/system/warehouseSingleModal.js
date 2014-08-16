groovepacks_controllers.
controller('warehousesSingleModal', [ '$scope', 'warehouse_data', 'warehouse_id', '$state', '$stateParams','$modal', '$modalInstance', '$timeout', 'hotkeys', 'warehouses','auth','notification',
function(scope,warehouse_data,warehouse_id,$state,$stateParams,$modal, $modalInstance,$timeout,hotkeys,warehouses,auth, notification) {

    var myscope = {};

    /**
    * Public methods
    */

    scope.ok = function() {
        $modalInstance.close("ok-button-click");
    };

    scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
    };

    myscope.update = function(reason) {
        if(reason == "cancel-button-click") {
            myscope.rollback();
        } else if(typeof scope.warehouses.single.inv_wh_info.id != "undefined")  {
            scope.update_single_warehouse(false);
        }
    };

    scope.warehouse_single_details = function(id,new_rollback) {
        for(var i =0; i< scope.warehouses.list.length; i++) {
            if(scope.warehouses.list[i].info.id == id) {
                scope.warehouses.current = parseInt(i);
                break;
            }
        }
        return warehouses.single.get(id,scope.warehouses).then(function(data) {
            scope.edit_status = true;
            warehouses.list.get_available_users(scope.warehouses);
            if(typeof new_rollback == 'boolean' && new_rollback) {
                warehouses.model.reset_single(myscope);
                angular.copy(scope.warehouses.single,myscope.single);
            }
        });
    };

    scope.user_permissions = function(user) {
        //if in edit mode, then update the server
        if(scope.edit_status) {
            warehouses.single.user_permissions(user, scope.warehouses);
        }
    };

    scope.update_single_warehouse = function() {
        if (scope.edit_status) {
            return warehouses.single.update(scope.warehouses);
        } else {
            return warehouses.single.create(scope.warehouses).success(function(data) {
                console.log(data);
                if(data.status && data.inv_wh_info.id) {
                    scope.warehouses.single.inv_wh_info.id = data.inv_wh_info.id;
                    scope.edit_status = true;
                }
            });
        }
    };


    myscope.rollback = function() {
        warehouses.model.reset_single(scope.warehouses);
        angular.copy(myscope.single,scope.warehouses.single);
        scope.update_single_warehouse();
    };

    /**
    * private properties
    */


    myscope.up_key = function(event) {
        event.preventDefault();
        event.stopPropagation();
        if(warehouse_id != 0) {
            if(scope.warehouses.current > 0) {
                myscope.load_item(scope.warehouses.current -1);
            } else {
                alert("Already at the top of the list");
            }
        }
    };

    myscope.down_key = function (event) {
        event.preventDefault();
        event.stopPropagation();
        if(warehouse_id != 0) {
            if(scope.warehouses.current < scope.warehouses.list.length - 1) {
                myscope.load_item(scope.warehouses.current +1);
            } else {
                alert("Already at the bottom of the list");
            }
        }
    };

    myscope.load_item = function(id) {
        scope.warehouse_single_details(scope.warehouses.list[id].info.id, true);
    };


    myscope.init = function() {
        scope.warehouses = warehouse_data;
        scope.auth = auth;
        warehouses.model.reset_single(scope.warehouses);
        //All tabs


        /**
        * Public properties
        */

        if(warehouse_id == 0) {
            scope.edit_status = false;
            warehouses.list.get_available_users(scope.warehouses);
        } else {
            scope.edit_status = true;
            scope.warehouse_single_details(warehouse_id,true);
        }

        $modalInstance.result.then(myscope.update,myscope.update);
        hotkeys.bindTo(scope).add({
            combo: 'up',
            description: 'Previous warehouse',
            callback: myscope.up_key
        }).add({
            combo: 'down',
            description: 'Next warehouse',
            callback: myscope.down_key
        }).add({
            combo: 'esc',
            description: 'Save and close modal',
            callback: function(){}
        });
    };

    myscope.init();
}]);
