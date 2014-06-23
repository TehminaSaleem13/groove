groovepacks_controllers. 
controller('warehousesCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', '$modal', 'warehouses',
function( $scope, $http, $timeout, $location, $state, $cookies,$modal, warehouses) {

    var myscope = {};

    $scope.select_all_toggle = function(val) {
        $scope.warehouses.setup.select_all = val;
        for (var i=0; i< $scope.warehouses.list.length; i++) {
            $scope.warehouses.list[i].checked = $scope.warehouses.setup.select_all;
        }
    };

    $scope.warehouse_change_status = function(status) {
        $scope.warehouses.setup.status = status;
        return warehouses.list.update('update_status',$scope.warehouses).then(function(data) {
            $scope.warehouses.setup.status = "";
            myscope.get_warehouses();
        });
    };

    $scope.warehouse_delete = function() {
        return warehouses.list.update('delete',$scope.warehouses).then(function(data) {
            myscope.get_warehouses();
        });
    };


    $scope.create_warehouse = function() {
        myscope.handle_click_fn({info:{id:0}});
    };

    myscope.handlesort = function(value) {
        myscope.warehouse_setup_opt('sort',value);
    };


    myscope.warehouse_setup_opt = function(type,value) {
        warehouses.setup.update($scope.warehouses.setup,type,value);
        myscope.get_warehouses();
    };

    myscope.get_warehouses = function() {
        warehouses.list.get($scope.warehouses);
    };

    myscope.handle_click_fn =function(row,event) {
        if(typeof event !='undefined') {
            event.stopPropagation();
        }
        var edit_modal = $modal.open({
             templateUrl: '/assets/views/modals/settings/system/warehouse.html',
             controller: 'warehousesSingleModal',
             size:'lg',
             resolve: {
                 warehouse_data: function(){return $scope.warehouses},
                 warehouse_id: function(){return row.info.id}
             }
         });
        edit_modal.result.finally(myscope.get_warehouses);
    };

    myscope.init = function() {
        $scope.setup_page('system','show_warehouses');
        $scope.warehouses = warehouses.model.get();
		myscope.get_warehouses();

        $scope.gridOptions = {
            identifier:'warehouse_settings',
            select_all: $scope.select_all_toggle,
            draggable:false,
            sortable:true,
            selectable:true,
            sort_func: myscope.handlesort,
            setup: $scope.warehouses.setup,
            functions: {
                name: myscope.handle_click_fn
            },
            all_fields: {
                'info.name': {
                    name: "Name",
                    grid_bind: '<a href="" ng-click="options.functions.name(row,$event)">{{row.info.name}}</a>',
                    class:''
                },

                'info.location': {
                    name: "Location",
                    grid_bind: '<span>{{row.info.location}}</span>',
                    class:''
                },
                'info.status': {
                    name: "Status",
                    grid_bind: '<span class="label label-default" ng-class="{\'label-success\': row.info.status==\'active\'}">' +
                               '{{row.info.status}}' +
                               '</span>',
                    class:''
                }
            }
        };

        $scope.$watch('warehouses.setup.search',myscope.get_warehouses);
    };

	myscope.init();
}]);
