groovepacks.config(['$stateProvider', '$urlRouterProvider','hotkeysProvider','cfpLoadingBarProvider','$translateProvider',
    function($stateProvider, $urlRouterProvider,hotkeysProvider,cfpLoadingBarProvider,$translateProvider) {

    $urlRouterProvider.otherwise("/home");
    $urlRouterProvider.when('/settings/', '/settings/stores');
    $urlRouterProvider.when('/settings', '/settings/stores');
    $urlRouterProvider.when('/scanandpack/rfp/', '/scanandpack');
    $urlRouterProvider.when('/scanandpack/rfp', '/scanandpack');
    $urlRouterProvider.when('/orders/', '/orders/awaiting/1');
    $urlRouterProvider.when('/orders', '/orders/awaiting/1');
    $urlRouterProvider.when('/orders/:filter/', '/orders/:filter/1');
    $urlRouterProvider.when('/orders/:filter', '/orders/:filter/1');
    $urlRouterProvider.when('/orders/:filter/:page/', '/orders/:filter/:page');
    $urlRouterProvider.when('/products/', '/products/product/active/1');
    $urlRouterProvider.when('/products', '/products/product/active/1');
    $urlRouterProvider.when('/products/:type/', '/products/:type/active/1');
    $urlRouterProvider.when('/products/:type', '/products/:type/active/1');
    $urlRouterProvider.when('/products/:type/:filter/', '/products/:type/:filter/1');
    $urlRouterProvider.when('/products/:type/:filter', '/products/:type/:filter/1');
    $urlRouterProvider.when('/products/:type/:filter/:page/', '/products/:type/:filter/:page');
    $urlRouterProvider.when('/system/', '/system/general');
    $urlRouterProvider.when('/system', '/system/general');

    $stateProvider
        .state('home',{url:'/home'})
        .state('orders', {url: '/orders', templateUrl: '/assets/views/showorders.html', controller: 'ordersCtrl'})
        .state('orders.filter', {url: '/{filter:all|awaiting|onhold|serviceissue|cancelled|scanned}',
                       template:"<div ui-view></div>", abstract:true})
        .state('orders.filter.page', {url: '/{page:[0-9]+}', template:"<div ui-view></div>",
                       controller: 'ordersFilterCtrl'})
        .state('orders.filter.page.single', {url: '/{order_id:[0-9]+}',template:"<div ui-view></div>",
                       controller:'ordersSingleCtrl'})

        .state('products',{url:'/products', templateUrl: '/assets/views/showproducts.html', controller: 'productsCtrl'})
        .state('products.type',{url:'/{type:product|kit}',template:"<div ui-view></div>",abstract:true})
        .state('products.type.filter', {url:'/{filter:all|active|inactive|new}', template:"<div ui-view></div>",
                       abstract:true})
        .state('products.type.filter.page', {url: '/{page:[0-9]+}', template:"<div ui-view></div>",
                       controller: 'productsFilterCtrl'})
        .state('products.type.filter.page.single', {url: '/{product_id:[0-9]+}', params:{new_product:{value:false}}, template:"<div ui-view></div>",
                       controller:'productsSingleCtrl'})

        .state('scanpack',{url: '/scanandpack', templateUrl: '/assets/views/scanpack/base.html', controller: 'scanPackCtrl'
                       ,abstract:true})
        .state('scanpack.rfo',{url: '', templateUrl:'/assets/views/scanpack/multi.html', controller: 'scanPackRfoCtrl'})
        .state('scanpack.rfp',{url: '/rfp/:order_num', templateUrl:"/assets/views/scanpack/rfpbase.html",  controller: 'scanPackRfpCtrl',
                       abstract:true })
        .state('scanpack.rfp.default', {url: '', controller:'scanPackRfpDefaultCtrl',
                       templateUrl:'/assets/views/scanpack/rfpdefault.html'})
        .state('scanpack.rfp.tracking', {url: '/tracking', templateUrl:'/assets/views/scanpack/multi.html',
                       controller:'scanPackTrackingCtrl'})
        .state('scanpack.rfp.product_edit', {url: '/product_edit', templateUrl:'/assets/views/scanpack/productedit.html',
                       controller:'scanPackProductEditCtrl'})
        .state('scanpack.rfp.product_edit.single', {url: '/{product_id:[0-9]+}', template:'', controller:'productsSingleCtrl'})
        .state('scanpack.rfp.confirmation',{url:'/confirmation',controller:'scanPackConfCtrl',
                       templateUrl:'/assets/views/scanpack/multi.html', abstract:true})
        .state('scanpack.rfp.confirmation.order_edit',{url:'/order_edit'})
        .state('scanpack.rfp.confirmation.product_edit',{url:'/product_edit'})
        .state('scanpack.rfp.confirmation.cos',{url:'/cos'})

        .state('settings',{url: '/settings', templateUrl:'/assets/views/settings/base.html', controller:'settingsCtrl', abstract:true })

        .state('settings.detailed_import', {url:'/detailed_import',templateUrl:'/assets/views/settings/csv_detailed.html',
            controller:'csvDetailed'})

        .state('settings.users',{url: '/users', templateUrl: '/assets/views/settings/users.html', controller: 'usersCtrl'})
        .state('settings.users.create',{url: '/create', controller: 'usersSingleCtrl'})
        .state('settings.users.single',{url:'/{user_id:[0-9]+}',controller:'usersSingleCtrl'})
        .state('settings.stores', {url:'/stores', templateUrl:'/assets/views/settings/stores.html', controller: 'storesCtrl'})
        .state('settings.stores.ebay', {
                       url:'/ebay?ebaytkn&tknexp&username&redirect&editstatus&name&status&storetype&storeid&inventorywarehouseid&importimages&importproducts&messagetocustomer&tenantname',
                       controller: 'storeSingleCtrl' })
        .state('settings.stores.create', {url:'/create', controller: 'storeSingleCtrl'})
        .state('settings.stores.single', {url:'/{storeid:[0-9]+}', controller: 'storeSingleCtrl'})

        .state('settings.system',{url:'/system', template:'<div ui-view></div>', abstract:true})
        .state('settings.system.general', {url:'/general',templateUrl:'/assets/views/settings/system/general.html',
                controller:'generalSettingsCtrl'})
        .state('settings.system.scan_pack', {url:'/scan_pack',templateUrl:'/assets/views/settings/system/scan_pack.html',
                controller:'scanPackSettingsCtrl'})
        .state('settings.system.backup', {url:'/backup', templateUrl:'/assets/views/settings/system/backup.html',
                       controller:'showBackupCtrl'})
        .state('settings.system.order_exception', {url:'/order_exception', templateUrl:'/assets/views/settings/system/order_exception.html',
                       controller:'exportOrderExceptionCtrl'})
        .state('settings.system.warehouses', {url:'/warehouses',templateUrl:'/assets/views/settings/system/warehouses.html',
            controller:'warehousesCtrl'});

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
                }
            }

        });
    }]);
