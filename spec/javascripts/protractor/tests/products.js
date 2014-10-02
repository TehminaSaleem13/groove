describe('Products:',function() {

    describe('List:', function() {
        beforeEach(function(){
            element(by.cssContainingText('.top-nav-bar a','Products')).click();
        });

        it('Url should match active list',function() {
            expect(browser.getLocationAbsUrl()).toMatch('/#/products/product/active/1');
        });

        it('All panel titles should match',function() {
            expect(element.all(by.css('.panel-title')).getText()).toEqual(['Products','Kits','Inventory Warehouse Count']);
        });

        it('Active tab should have class .active',function(){
            expect(element(by.css('.panel-collapse.in .panel-body li.active')).getText()).toEqual('Active Products');
        });

        it('Clicking All tab should change url and css',function(){
            element(by.cssContainingText('.panel-collapse.in .panel-body li','Show All')).click();
            expect(element(by.css('.panel-collapse.in .panel-body li.active')).getText()).toEqual('Show All');
            expect(browser.getLocationAbsUrl()).toMatch('/#/products/product/all/1');
        });

        it('Clicking Create should open modal',function() {
            element(by.cssContainingText('.panel-collapse.in .panel-body li','Create')).click();
            expect(browser.getLocationAbsUrl()).toMatch('/#/products/product/new/1/1');
            expect(element(by.css('body')).getAttribute('class')).toMatch('modal-open');
            expect(element(by.css('.modal-dialog')).isDisplayed()).toBeTruthy();
        });
    });
    describe('Modal:',function() {
        describe('Name:',function() {
            var name = {};

            name.input = element(by.model('products.single.basicinfo.name'));
            name.text = element(by.binding('products.single.basicinfo.name'));
            name.default = 'New Product';
            name.new = 'Product Test 1';

            it('Product should have the name New Product',function() {
                expect(name.input.getAttribute('value')).toEqual(name.default);
                expect(name.text.getText()).toEqual(name.default);
            });

            it('Editing name should work',function() {
                name.input.clear();
                name.input.sendKeys(name.new);
                expect(name.input.getAttribute('value')).toEqual(name.new);
                expect(name.text.getText()).toEqual(name.new);
            });

            it('Reloading the modal should\'ve saved the name', function() {
                name.text.click();
                browser.refresh();
                expect(name.text.getText()).toEqual(name.new);
                expect(name.input.getAttribute('value')).toEqual(name.new);
            });
        });

    });


});
