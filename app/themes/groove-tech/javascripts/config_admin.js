groovepacks_admin.config(['$stateProvider', '$urlRouterProvider','hotkeysProvider','cfpLoadingBarProvider','$translateProvider','$urlMatcherFactoryProvider', 'ngClipProvider',
function($stateProvider, $urlRouterProvider,hotkeysProvider,cfpLoadingBarProvider,$translateProvider,$urlMatcherFactoryProvider, ngClipProvider) {

    ngClipProvider.setPath("/swf/ZeroClipboard.swf");

    $urlRouterProvider.otherwise("/home");
    $urlRouterProvider.when('/tools', '/tools/admin_tools');

    $urlMatcherFactoryProvider.strictMode(false);
    $stateProvider
        .state('home',{url:'/home'})
        .state('tools',{url:'/tools/admin_tools', templateUrl:'/assets/admin_views/base.html', controller:'adminToolsCtrl'})
        // .state('tools.admin_tools',{url:'/admin_tools',templateUrl:'/assets/admin_views/base.html', controller:'adminToolsCtrl'});

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
                    console.log('from.name: ' + from.name);
                    console.log('to.name: ' + to.name);
                    var result = auth.prevent(to.name,toParams);
                    console.log('result.to: ' + result.to);
                    console.log('result.params: ' + result.params);
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
                    if (to.name ==='products' || to.name ==='products.type' || to.name ==='products.type.filter') {
                        e.preventDefault();
                        $state.go('products.type.filter.page');
                    } else if(to.name === 'orders' || to.name === 'orders.filter') {
                        e.preventDefault();
                        $state.go('orders.filter.page');

                    }
                }
            }

        });
    }]);
