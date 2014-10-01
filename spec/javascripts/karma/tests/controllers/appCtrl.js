describe('Unit: appCtrl', function() {
    beforeEach(module('groovepacks'));
    var ctrl,scope;
    beforeEach(inject(function($controller,$rootScope) {
        scope = $rootScope.$new();
        ctrl = $controller('appCtrl', {
            $scope: scope
        });
    }));

    it('should show no active tab',function(){
        expect(scope.is_active_tab('')).toBe(true);
    });

    using('tabs',['orders','products','settings','scanpack'],function(tab){
        it('should not show active tab',function(){
            expect(scope.is_active_tab(tab)).toBe(false);
        });
    });
});
