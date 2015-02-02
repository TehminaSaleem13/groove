groovepacks_controllers.
controller('scanPackSettingsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', 'scanPack', 'groov_translator',
function( $scope, $http, $timeout, $location, $state, $cookies, scanPack,groov_translator) {

    var myscope = {};


    myscope.init = function() {
        $scope.setup_page('system','scan_pack');
        $scope.translations = {
            "headings":{
                "options": "",
                "feedback": "",
                "scan_actions": "",
                "scan_actions_sub_head": ""
            },
            "labels":{
                "enable_click_sku":"",
                "ask_tracking_number":"",
                "show_success_image":"",
                "show_order_complete_image":"",
                "show_fail_image":"",
                "for":"",
                "seconds":"",
                "play_success_sound":"",
                "play_fail_sound":"",
                "play_order_complete_sound":"",
                "scan":"",
                "skip_code":"",
                "note_from_packer_code":"",
                "service_issue_code":"",
                "restart_code":""
            },
            "tooltips" :{
                "enable_click_sku":"",
                "ask_tracking_number":"",
                "feedback":"",
                "skip_code":"",
                "note_from_packer_code":"",
                "service_issue_code":"",
                "restart_code":""
            }
        };
        groov_translator.translate('settings.system.scan_pack',$scope.translations);
        $scope.scan_pack = scanPack.settings.model();
        scanPack.settings.get($scope.scan_pack);
    };

    $scope.update_settings = function() {
        scanPack.settings.update($scope.scan_pack);
    };

	myscope.init();
}]);
