groovepacks_controllers.
  controller('showBackupCtrl', ['$scope', '$timeout', 'backup',
    function ($scope, $timeout, backup) {
      var myscope = {};

      myscope.init = function () {
        $scope.setup_page('backup_restore', 'backup');
        $scope.backup_restore = backup.model.get();


        $scope.$on("fileSelected", function (event, args) {
          if (args.name == "importbackupfile") {
            $scope.$apply(function () {
              $scope.backup_restore.data.file = args.file;
              $("input[type='file']").val('');
            });
            backup.restore($scope.backup_restore.data).then(function(response){
              setTimeout(function(){
                myscope.init();
              }, 300);
            });
          }
        });
      };

      $scope.export_csv = function() {
        console.log('export_csv.....')
        backup.back_up().then(function(){
          myscope.init();
        });
      };
      myscope.init();
    }]);
