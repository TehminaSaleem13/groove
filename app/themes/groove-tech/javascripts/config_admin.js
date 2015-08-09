groovepacks_admin.config(['$stateProvider', '$urlRouterProvider','hotkeysProvider','cfpLoadingBarProvider','$translateProvider','$urlMatcherFactoryProvider', 'ngClipProvider',
function($stateProvider, $urlRouterProvider,hotkeysProvider,cfpLoadingBarProvider,$translateProvider,$urlMatcherFactoryProvider, ngClipProvider) {

    ngClipProvider.setPath("/swf/ZeroClipboard.swf");

    $urlRouterProvider.otherwise("/home");
    $urlRouterProvider.when('/tools', '/admin_tools');

    $urlMatcherFactoryProvider.strictMode(false);
    $stateProvider
        .state('home',{url:'/home'})
        .state('tools',{url:'/admin_tools', templateUrl:'/assets/admin_views/base.html', controller:'adminToolsCtrl'})
        .state('tools.type',{url:'/{type:tenant}', params:{type:'tenant'}, template:"<div ui-view></div>",abstract:true})
        .state('tools.type.page', {url: '/{page:[0-9]+}', params:{page:'1'}, template:"<div ui-view></div>",
                       controller: 'tenantsFilterCtrl'})
        .state('tools.type.page.single', {url: '/{tenant_id:[0-9]+}',template:"<div ui-view></div>",
                       controller:'tenantsSingleCtrl'})
        
    hotkeysProvider.cheatSheetHotkey =['mod+f1','g','G'];
    hotkeysProvider.cheatSheetDescription = '(or \'g\') Show / hide this help menu';
    cfpLoadingBarProvider.includeSpinner = false;
    $translateProvider.useStaticFilesLoader({
        prefix: '/assets/translations/locale-',
        suffix: '.json'
    });
    $translateProvider.preferredLanguage('en').fallbackLanguage('en');
}]).run(['$rootScope','$state','$urlRouter','$timeout','auth',function($rootScope, $state, $urlRouter, $timeout, auth) {
        $rootScope.$on('$stateChangeStart', function(e, to,toParams,from,fromParams) {
            if(jQuery.isEmptyObject(auth.get())) {
                if(!from.abstract || from.name =='') {
                    e.preventDefault();
                }
                auth.check().then(function() {
                    var result = auth.prevent(to.name,toParams);
                    if (result && result.to) {
                        $state.go(result.to, result.params);
                    } else if (!jQuery.isEmptyObject(auth.get())){
                        $urlRouter.sync();
                    }
                })
            } else {
                var result = auth.prevent(to.name,toParams);
                if (result && result.to) {
                    e.preventDefault();
                    $state.go(result.to, result.params);
                } else {
                    if (to.name ==='tools' || to.name ==='tools.type') {
                        e.preventDefault();
                        $state.go('tools.type.page');
                    } 
                }
            }

        });
    }]);
