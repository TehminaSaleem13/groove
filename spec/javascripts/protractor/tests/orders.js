describe('Orders:',function() {

    describe('List:',function() {
        beforeEach(function() {
            element.all(by.cssContainingText('.top-nav-bar a','Orders')).first().click();
        });
        it('Url should match awaiting list',function() {
            expect(browser.getLocationAbsUrl()).toMatch('/#/orders/awaiting/1');
        });
        it('First title should be orders',function() {
            expect(element.all(by.css('.panel-title')).first().getText()).toEqual('Orders');
        });
    });


});
