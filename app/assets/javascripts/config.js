groovepacks.config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {

    $urlRouterProvider.otherwise("/home");
    $urlRouterProvider.when('/settings/', '/settings/showusers');
    $urlRouterProvider.when('/settings', '/settings/showusers');
    $urlRouterProvider.when('/scanandpack/rfp', '/scanandpack');
    $urlRouterProvider.when('/scanandpack/rfp/', '/scanandpack');
    $stateProvider
        .state('home',{url:'/home'})
        .state('orders', {url: '/orders', templateUrl: '/assets/partials/showorders.html', controller: 'showOrdersCtrl'})
        .state('products',{url:'/products', templateUrl: '/assets/partials/showproducts.html', controller: 'showProductsCtrl'})
        .state('scanpack',{url: '/scanandpack', templateUrl: '/assets/partials/showscanpack.html', controller: 'showScanPackCtrl',abstract:true})
        .state('scanpack.rfo',{url: '', templateUrl:'/assets/partials/scanpackmulti.html', controller: 'scanPackRfoCtrl'})
        .state('scanpack.rfp',{url: '/rfp/:order_num', template:"<div ui-view></div>",  controller: 'scanPackRfpCtrl', abstract:true })
        .state('scanpack.rfp.default', {url: '', controller:'scanPackRfpDefaultCtrl', templateUrl:'/assets/partials/scanpackrfp.html'})
        .state('scanpack.rfp.tracking', {url: '/tracking', templateUrl:'/assets/partials/scanpackmulti.html', controller:'scanPackTrackingCtrl'})
        .state('scanpack.rfp.product_edit', {url: '/product_edit', templateUrl:'/assets/partials/scanpackproductedit.html', controller:'scanPackProductEditCtrl'})
        .state('scanpack.rfp.product_edit.product', {url: '/:id', template:'', controller:'scanPackProductCtrl'})
        .state('scanpack.rfp.confirmation',{url:'/confirmation',controller:'scanPackConfCtrl',templateUrl:'/assets/partials/scanpackmulti.html', abstract:true})
        .state('scanpack.rfp.confirmation.order_edit',{url:'/order_edit'})
        .state('scanpack.rfp.confirmation.product_edit',{url:'/product_edit'})
        .state('scanpack.rfp.confirmation.cos',{url:'/cos'})
        .state('settings',{url: '/settings', templateUrl:'/assets/partials/settings.html', controller:'showSettingsCtrl', abstract:true })
        .state('settings.showusers',{url: '/showusers', templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'})
        .state('settings.showusers.create',{url: '/create', controller: 'createUserCtrl'})
        .state('settings.showstores', {url:'/showstores', templateUrl:'/assets/partials/showstores.html', controller: 'showStoresCtrl'})
        .state('settings.showstores.ebay', {url:'/ebay?ebaytkn&tknexp&username&redirect&editstatus&name&status&storetype&storeid&inventorywarehouseid', controller: 'createStoreCtrl' })
        .state('settings.showstores.create', {url:'/create', controller: 'createStoreCtrl'})
        .state('settings.showstores.backup', {url:'/backup',controller:'showBackupCtrl'})
        .state('settings.warehouses', {url:'/showwarehouses',templateUrl:'/assets/partials/showwarehouses.html',
                controller:'showWarehousesCtrl'});
}]).run(['$rootScope','$state','$urlRouter','$timeout','auth',function($rootScope, $state, $urlRouter, $timeout, auth) {
        $rootScope.$on('$stateChangeStart', function(e, to,toParams,from,fromParams) {
            if(jQuery.isEmptyObject(auth.get())) {
                if(!from.abstract) {
                    e.preventDefault();
                    console.log("prevented");
                }
                auth.check().then(function() {
                    var result = auth.prevent(to.name,toParams);
                    if (result && result.to) {
                        $state.go(result.to, result.params);
                    } else {
                        //$urlRouter.sync();
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
