groovepacks_admin_controllers.
controller('selectionModal', [ '$scope', 'selected_data','selected_table_options', '$modalInstance',
function(scope,selected_data,selected_table_options,$modalInstance) {
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

    myscope.init = function() {
        scope.selected = selected_data;

        scope.gridOptions = selected_table_options;

        scope.$watch('selected',function() {
           if(scope.selected.length == 0) {
               scope.ok();
           }
        },true);
    };
    myscope.init();
}]);
