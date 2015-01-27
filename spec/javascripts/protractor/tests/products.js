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
            expect(browser.getLocationAbsUrl()).toContain('/#/products/product/new/1/');
            expect(element(by.css('body')).getAttribute('class')).toMatch('modal-open');
            expect(element(by.css('.modal-dialog')).isDisplayed()).toBeTruthy();
        });
    });
    describe('Modal:',function() {
        var name_text = element(by.binding('products.single.basicinfo.name'));
        describe('Name:',function() {
            var name = {};
            name.input = element(by.model('products.single.basicinfo.name'));
            name.default = 'New Product';
            name.new = 'Product Test 1';

            it('Product should have the name New Product',function() {
                expect(name.input.getAttribute('value')).toEqual(name.default);
                expect(name_text.getText()).toEqual(name.default);
            });

            it('Editing name should work',function() {
                name.input.clear();
                name.input.sendKeys(name.new);
                expect(name.input.getAttribute('value')).toEqual(name.new);
                expect(name_text.getText()).toEqual(name.new);
            });

            it('Reloading the modal should\'ve saved the name', function() {
                name_text.click();
                browser.refresh();
                expect(name_text.getText()).toEqual(name.new);
                expect(name.input.getAttribute('value')).toEqual(name.new);
            });
        });
        
        describe('Sku:',function(){
            var sku = {};
        });      

        describe('Special Instructions:',function() {
            var special_instructions = {};
            special_instructions.textarea = element(by.model('products.single.basicinfo.spl_instructions_4_packer'));

            // packing_placement is to blur out the special_instructions textarea field, so that the changes will be saved
            var packing_placement = {};
            packing_placement.input = element(by.model('products.single.basicinfo.packing_placement'));
            
            special_instructions.default = '';
            special_instructions.new = 'Test Instructions';

            it('Product should have empty test instructions',function() {
                expect(special_instructions.textarea.getAttribute('value')).toEqual(special_instructions.default);
            });

            it('Editing name should work',function() {
                special_instructions.textarea.clear();
                special_instructions.textarea.sendKeys(special_instructions.new);
                expect(special_instructions.textarea.getAttribute('value')).toEqual(special_instructions.new);
            });

            it('Reloading the modal should\'ve saved the test instructions', function() {
                // blur out special_instructions textarea field
                packing_placement.input.click();
                browser.refresh();
                expect(special_instructions.textarea.getAttribute('value')).toEqual(special_instructions.new);
            });
        });
        
        describe('Packing Placement:',function() {
            var packing_placement = {};
            packing_placement.input = element(by.model('products.single.basicinfo.packing_placement'));

            // special_instructions is to blur out the packing_placement input field, so that the changes will be saved
            var special_instructions = {};
            special_instructions.textarea = element(by.model('products.single.basicinfo.spl_instructions_4_packer'));
            
            packing_placement.default = '50';
            packing_placement.new = '55';
            packing_placement.bad ='asd';

            

            it('Editing packing placement should work',function() {
                packing_placement.input.click();
                packing_placement.input.clear();
                packing_placement.input.sendKeys(packing_placement.new);
                expect(packing_placement.input.getAttribute('value')).toEqual(packing_placement.new);
            });

            it('Reloading the modal should\'ve saved the packing placement value', function() {
                // blur out packing_placement input field
                special_instructions.textarea.click();
                browser.refresh();
                expect(packing_placement.input.getAttribute('value')).toEqual(packing_placement.new);
            });

            it('Feeding non numbers to packing placement should reset to default',function() {
                packing_placement.input.clear();
                packing_placement.input.sendKeys(packing_placement.default);
                special_instructions.textarea.click();
                packing_placement.input.clear();
                packing_placement.input.sendKeys(packing_placement.bad);

                // blur out packing_placement input field
                special_instructions.textarea.click();
                expect(packing_placement.input.getAttribute('value')).toEqual(packing_placement.default);
            });
        });

    });


});
