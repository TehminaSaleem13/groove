groovepacks_controllers.controller('orderExportCtrl', [ '$scope','$window',function($scope,$window) {
    var myscope = {};

    myscope.init = function() {
        $scope.setup_page('order_export');
    };
    myscope.init();
}]);
