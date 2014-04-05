groovepacks.config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {

    $urlRouterProvider.otherwise("/home");
    $urlRouterProvider.when('/settings', '/settings/showusers');
    $stateProvider
        .state('home',{url:'/home'})
        .state('orders', {url: '/orders', templateUrl: '/assets/partials/showorders.html', controller: 'showOrdersCtrl'})
        .state('products',{url:'/products', templateUrl: '/assets/partials/showproducts.html', controller: 'showProductsCtrl'})
        .state('scanpack',{url: '/scanandpack', templateUrl: '/assets/partials/showscanandpack.html', controller: 'showScanPackCtrl'})
        .state('settings',{url: '/settings', templateUrl:'/assets/partials/settings.html', controller:'showSettingsCtrl', abstract:true })
        .state('settings.showusers',{url: '/showusers', templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'})
        .state('settings.showusers.create',{url: '/create', controller: 'createUserCtrl'})
        .state('settings.showstores', {url:'/showstores', templateUrl:'/assets/partials/showstores.html', controller: 'showStoresCtrl'})
        .state('settings.showstores.create', {url:'/create', controller: 'createStoreCtrl'})
        .state('settings.showstores.backup', {url:'/backup',controller:'showBackupCtrl'})
        .state('settings.warehouses', {url:'/showwarehouses',templateUrl:'/assets/partials/showwarehouses.html', 
                controller:'showWarehousesCtrl'})
        .state('settings.general', {url:'/general',templateUrl:'/assets/partials/generalsettings.html', 
                controller:'generalSettingsCtrl'});
}]).run(['$rootScope','$state','$urlRouter','$timeout','auth',function($rootScope, $state, $urlRouter, $timeout, auth) {
        $rootScope.$on('$stateChangeStart', function(e, to,toParams,from,fromParams) {
            if(jQuery.isEmptyObject(auth.get())) {
                e.preventDefault();
                auth.check().then(function() {
                    var result = auth.prevent(to.name,toParams);
                    if (result && result.to) {
                        $state.go(result.to, result.params);
                    } else {
                        $urlRouter.sync();
                    }
                })
            } else {
                var result = auth.prevent(to.name,toParams);
                if (result && result.to) {
                    e.preventDefault();
                    $state.go(result.to, result.params);
                }
            }

        });
    }]);
