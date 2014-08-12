groovepacks_controllers.
controller('storesCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','stores', 'warehouses',
function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, stores, warehouses) {

    var myscope = {};

    $scope.select_all_toggle = function(val) {
        $scope.stores.setup.select_all = val;
        for( var store_index=0; store_index<= $scope.stores.list.length-1; store_index++) {
            $scope.stores.list[store_index].checked = $scope.stores.setup.select_all;
        }
    };


    $scope.store_change_status = function(status) {
        $scope.stores.setup.status = status;
        return stores.list.update('update_status',$scope.stores).then(function(data) {
            $scope.stores.setup.status = "";
            myscope.get_stores();
        });
    };

    $scope.store_delete = function() {
        return stores.list.update('delete',$scope.stores).then(function(data) {
            myscope.get_stores();
        });
    };

    $scope.store_duplicate = function() {
        return stores.list.update('duplicate',$scope.stores).then(function(data) {
            myscope.get_stores();
        });

    };



    myscope.handlesort = function(predicate) {
        myscope.store_setup_opt('sort',predicate);
    };

    myscope.store_setup_opt = function(type,value) {
        stores.setup.update($scope.stores.setup,type,value);
        myscope.get_stores();
    };

    myscope.get_stores = function() {
        return stores.list.get($scope.stores).then(function(){
            $scope.select_all_toggle();
        });
    };

    myscope.init = function() {
        $scope.setup_page("show_stores");
        $scope.stores = stores.model.get();
        myscope.get_stores();
        $scope.gridOptions = {
            identifier:'store_settings',
            select_all: $scope.select_all_toggle,
            draggable:false,
            sortable:true,
            selectable:true,
            sort_func: myscope.handlesort,
            setup: $scope.stores.setup,
            all_fields: {
                name: {
                    name: "Name",
                    class:''
                },
                status: {
                    name:"Status",
                    transclude: '<span class="label label-default" ng-class="{\'label-success\': row.status}">' +
                               '<span ng-show="row.status" class="active">Active</span>' +
                               '<span ng-hide="row.status" class="inactive">Inactive</span>' +
                               '</span>',
                    class:''
                },
                store_type: {
                    name: "Type",
                    class:''
                }

            }
        };
        if(typeof $scope.current_user['can']!= 'undefined' && $scope.current_user.can('add_edit_stores')) {
            $scope.gridOptions.all_fields.name.transclude ='<a ui-sref="settings.stores.single({storeid:row.id})"' +
                                                          ' ng-click="$event.preventDefault();$event.stopPropagation();">{{row[field]}}</a>';
        }

        $scope.$watch('stores.setup.search',myscope.get_stores);
        $scope.$on("store-modal-closed",myscope.get_stores);
    };

    myscope.init();

    //$scope.init();
}]);
