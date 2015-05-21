groovepacks_admin_controllers.
controller('showBackupCtrl', [ '$scope', 'backup',
function( $scope,backup) {
    var myscope = {};

    myscope.init = function() {
        $scope.setup_page('backup_restore','backup');
        $scope.backup_restore = backup.model.get();



        $scope.$on("fileSelected", function (event, args) {
            if(args.name == "importbackupfile") {
                $scope.$apply(function () {
                    $scope.backup_restore.data.file = args.file;
                    $("input[type='file']").val('');
                });
                backup.restore($scope.backup_restore.data);
            }
        });

    };
    myscope.init();
}]);
