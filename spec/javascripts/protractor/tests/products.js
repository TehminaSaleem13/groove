describe('Products:',function() {
    var table = {};
    var edit = {};
    var status = {};
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
            // element(by.className("close-btn")).click();
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
                element(by.className("close-btn")).click();
            });
            it('deletes the newly created product, because it doesn\'t have sku and barcode',function(){
                table.list_table = element.all(by.tagName('table')).first();
                table.thead = table.list_table.element(by.tagName('thead'));
                table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                    table.titles_count = text.indexOf('Item Name');
                    element(by.cssContainingText('.panel-collapse.in .panel-body li','New')).click();
                    new selectFirstRowInList();
                    status.button = element.all(by.buttonText('Change Status')).first().click();
                    status.parent = status.button.element(by.xpath(".."));
                    status.ul = status.parent.element(by.tagName("ul"));
                    status.li = status.ul.all(by.tagName("li")).get(1).click();
                    element(by.cssContainingText('.panel-collapse.in .panel-body li','Inactive Products')).click();
                    new selectFirstRowInList();
                    edit.button = element.all(by.buttonText('Edit')).first().click();
                    edit.parent = edit.button.element(by.xpath(".."));
                    edit.ul = edit.parent.element(by.tagName("ul"));
                    edit.li = edit.ul.all(by.tagName("li")).get(0).click();
                    browser.switchTo().alert().accept();
                    element(by.cssContainingText('.panel-collapse.in .panel-body li','Active Products')).click();
                });
            });
        });
    });
    
    describe('Title:',function() {
        it('Right click on header should show list of titles',function() {
            var elem = {};
            element(by.cssContainingText('.panel-collapse.in .panel-body li','Active Products')).click();
            new showTitleList();
            elem.list_element = element.all(by.repeater('field in options.all_fields')).first();
            elem.parent1 = elem.list_element.element(by.xpath(".."));
            expect(elem.parent1.element(by.xpath("..")).getAttribute("class")).toEqual("clearfix open");
        });
        it('Click on a title in the list to view it in the table',function() {
            var elem = {};
            elem.list_elements = element.all(by.repeater('field in options.all_fields'));
            elem.list_elements.get(7).click();

            table.list_table = element.all(by.tagName('table')).first();
            table.thead = table.list_table.element(by.tagName('thead'));
            table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                expect(text).toContain('Tertiary Location');
                elem.list_elements = element.all(by.repeater('field in options.all_fields'));
                elem.list_elements.get(7).click();
            });
        });
    });
    describe('Select:',function() {
        it('Right click on the Barcode makes the field editable for the product',function() {
            var barcode = {};
            var column_no = 0;
            barcode.new = "BARCODE";
            new showTitleList();
            table.list_table = element.all(by.tagName('table')).first();
            table.thead = table.list_table.element(by.tagName('thead'));
            table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                table.titles_count = text.indexOf('Barcode');
                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();
                table.row.all(by.tagName('td')).get(table.titles_count).then(function(td) {
                    barcode.actual = td.getText();
                    browser.actions().mouseMove(td).perform();
                    browser.actions().click(protractor.Button.RIGHT).perform();
                    for (var i = 0; i<25; i++) {
                        browser.actions().sendKeys(protractor.Key.BACK_SPACE).perform();
                    }
                    browser.actions().sendKeys(barcode.new).perform();
                    table.exit_button = element(by.className("top-message"));
                    table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
                    expect(table.row.all(by.tagName('td')).get(table.titles_count).getText()).toContain(barcode.new);
                    table.row.all(by.tagName('td')).get(table.titles_count).then(function(td) {
                        browser.actions().mouseMove(td).perform();
                        browser.actions().click(protractor.Button.RIGHT).perform();
                        for (var i = 0; i<25; i++) {
                            browser.actions().sendKeys(protractor.Key.BACK_SPACE).perform();
                        }
                        browser.actions().sendKeys(barcode.actual).perform();
                        table.exit_button = element(by.className("top-message"));
                        table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
                    });
                });
            });
        });
        it('Duplicates the selected order item',function() {
            browser.executeScript('window.scrollTo(0,0);').then(function () {
                new selectFirstRowInList();
                table.list_table = element.all(by.tagName('table')).first();
                table.thead = table.list_table.element(by.tagName('thead'));
                table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                    table.titles_count = text.indexOf('Item Name');
                    table.tbody = element.all(by.tagName("tbody")).first();
                    table.row = table.tbody.all(by.tagName("tr")).first();
                    table.row.all(by.tagName('td')).get(table.titles_count).then (function(td) {
                        table.item_name = td.getText();

                        edit.button = element.all(by.buttonText('Edit')).first().click();
                        edit.parent = edit.button.element(by.xpath(".."));
                        edit.ul = edit.parent.element(by.tagName("ul"));
                        edit.li = edit.ul.all(by.tagName("li")).get(0).click();

                        table.tbody = element.all(by.tagName("tbody")).first();
                        table.row = table.tbody.all(by.tagName("tr")).first();
                        table.row.all(by.tagName('td')).get(table.titles_count).then (function(td1) {
                            table.item_name1 = td1.getText();
                            expect(table.item_name1).toContain(table.item_name);
                        });
                    });
                });
            })
        });
        it('Modifies the status of selected order item',function() {
            new selectFirstRowInList();
            table.list_table = element.all(by.tagName('table')).first();
            table.thead = table.list_table.element(by.tagName('thead'));
            table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                table.titles_count_item_name = text.indexOf('Order #')
                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();
                table.item_name = table.row.all(by.tagName('td')).get(table.titles_count_item_name).getText();
                
                status.button = element.all(by.buttonText('Change Status')).first().click();
                status.parent = status.button.element(by.xpath(".."));
                status.ul = status.parent.element(by.tagName("ul"));
                status.li = status.ul.all(by.tagName("li")).get(1).click();

                element(by.cssContainingText('.panel-collapse.in .panel-body li','Inactive Products')).click();

                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();
                table.item_name1 = table.row.all(by.tagName('td')).get(table.titles_count_item_name).getText();
                expect(table.item_name).toEqual(table.item_name1);
                // element(by.cssContainingText('.panel-collapse.in .panel-body li','Active Products')).click();
            });
        });
        it('Deletes the selected order item',function() {
            new selectFirstRowInList();
            table.list_table = element.all(by.tagName('table')).first();
            table.thead = table.list_table.element(by.tagName('thead'));
            table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                table.titles_count = text.indexOf('Item Name');
                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();

                table.row.all(by.tagName('td')).get(table.titles_count).then (function(td) {
                    table.item_name = td.getText();

                    edit.button = element.all(by.buttonText('Edit')).first().click();
                    edit.parent = edit.button.element(by.xpath(".."));
                    edit.ul = edit.parent.element(by.tagName("ul"));
                    edit.li = edit.ul.all(by.tagName("li")).get(0).click();
                    browser.switchTo().alert().accept();
                    element(by.cssContainingText('.panel-collapse.in .panel-body li','Active Products')).click();
                });
            });
        });
        it('Clicking on the \'Item Name\' opens the product modal',function() {
            table.list_table = element.all(by.tagName('table')).first();
            table.thead = table.list_table.element(by.tagName('thead'));
            table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                new openProductModal(text);
                expect(browser.getLocationAbsUrl()).toContain('/#/products/product/active/1/');
                element(by.className("close-btn")).click();
            });
        });
        it('Changing the status on product modal changes the status of the item',function() {
            table.list_table = element.all(by.tagName('table')).first();
            table.thead = table.list_table.element(by.tagName('thead'));
            table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                new openProductModal(text);
                table.status = element(by.cssContainingText('.modal-dialog.modal-lg .modal-content .modal-body .container-fluid.form-horizontal .product_single_top_table td','Status '));
                table.status.all(by.tagName('label')).get(1).click();
                element(by.className("close-btn")).click();
                element(by.cssContainingText('.panel-collapse.in .panel-body li','Inactive Products')).click();

                table.list_table = element.all(by.tagName('table')).first();
                table.thead = table.list_table.element(by.tagName('thead'));
                table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                    new getTitleName(text);
                    expect(table.item_name1).toEqual(table.item_name);
                });
                element(by.cssContainingText('.panel-collapse.in .panel-body li','Active Products')).click();
            });
        });
        it('Clicking the link changes the item to a kit',function() {
            table.list_table = element.all(by.tagName('table')).first();
            table.thead = table.list_table.element(by.tagName('thead'));
            table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                new openProductModal(text);
                table.change_to_kit = element(by.cssContainingText('.modal-dialog.modal-lg .modal-content .modal-body .container-fluid.form-horizontal .product_single_top_table td','Change'));
                table.change_to_kit.all(by.tagName('p')).first().all(by.tagName('a')).first().click();
                element(by.className("close-btn")).click();
                element(by.cssContainingText('.panel-heading .panel-title .accordion-toggle a','Kits')).click();
                element(by.cssContainingText('.panel-collapse.in .panel-body li','New Kits ')).click();
                table.list_table = element.all(by.tagName('table')).first();
                table.thead = table.list_table.element(by.tagName('thead'));
                table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                    new getTitleName(text);
                    expect(table.item_name1).toEqual(table.item_name);
                    table.row.all(by.tagName('td')).get(table.titles_count).all(by.tagName('div')).first().all(by.tagName('div')).first().click();
                    table.change_back_to_product = element(by.cssContainingText('.modal-dialog.modal-lg .modal-content .modal-body .container-fluid.form-horizontal .product_single_top_table td','back to'));
                    table.change_back_to_product.all(by.tagName('p')).get(1).all(by.tagName('a')).first().click();
                    element(by.className("close-btn")).click();
                    element(by.cssContainingText('.panel-heading .panel-title .accordion-toggle a','Products')).click();
                    element(by.cssContainingText('.panel-collapse.in .panel-body li','Active Products')).click();
                    table.list_table = element.all(by.tagName('table')).first();
                    table.thead = table.list_table.element(by.tagName('thead'));
                    table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                        new getTitleName(text);
                        expect(table.item_name1).toEqual(table.item_name);
                    });
                });
            });
        });
        // it('Modifying the available inventory in product modal reflects in the products list',function() {
        //     table.list_table = element.all(by.tagName('table')).first();
        //     table.thead = table.list_table.element(by.tagName('thead'));
        //     table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
        //         new openProductModal(text);
        //         element.all(by.cssContainingText('.modal-dialog.modal-lg .modal-content .modal-body .container-fluid.form-horizontal table','Warehouse Name')).first().then(function(inventory_table) {
        //             inventory_table.all(by.repeater('field in theads')).getText().then (function(text) {
        //                 table.titles_available_inv_count = text.indexOf('Available Inv');
        //                 table.tbody = inventory_table.all(by.tagName("tbody")).first();
        //                 table.row = table.tbody.all(by.tagName("tr")).first();
                    
        //                 table.row.all(by.tagName('td')).get(table.titles_available_inv_count).then(function(td) {
        //                     browser.actions().mouseMove(td).perform();
        //                     browser.actions().click(protractor.Button.RIGHT).perform();
        //                     browser.actions().sendKeys(protractor.Key.ARROW_UP).perform();

        //                     table.exit_button = element(by.className("top-message"));
        //                     table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
        //                     browser.sleep(1000);
        //                     table.available_inv = table.row.all(by.tagName('td')).get(table.titles_available_inv_count).getText();
        //                     element(by.className("close-btn")).click();
        //                     table.list_table = element.all(by.tagName('table')).first();
        //                     table.thead = table.list_table.element(by.tagName('thead'));
        //                     table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
        //                         table.titles_available_inv_count = text.indexOf('Avbl Inv');
        //                         table.tbody = element.all(by.tagName("tbody")).first();
        //                         table.row = table.tbody.all(by.tagName("tr")).first();
        //                         table.available_inv1 = table.row.all(by.tagName('td')).get(table.titles_available_inv_count).getText();
        //                         expect(String(table.available_inv1)).toEqual(String(table.available_inv).trim());
        //                     });
        //                 });
        //             });
        //         });
        //     });
        // });
    });
    var selectFirstRowInList = function() {
        table.tbody = element.all(by.tagName("tbody")).first();
        table.row = table.tbody.all(by.tagName("tr")).first();
        table.item_name = table.row.all(by.tagName('td')).get(table.titles_count).getText();
        table.row.click();
    }
    var openProductModal = function(text) {
        table.titles_count = text.indexOf('Item Name');
        table.tbody = element.all(by.tagName("tbody")).first();
        table.row = table.tbody.all(by.tagName("tr")).first();
        table.item_name = table.row.all(by.tagName('td')).get(table.titles_count).getText();
        table.row.all(by.tagName('td')).get(table.titles_count).all(by.tagName('div')).first().all(by.tagName('div')).first().click();
    }
    var getTitleName = function(text) {
        table.titles_count = text.indexOf('Item Name');
        table.tbody = element.all(by.tagName("tbody")).first();
        table.row = table.tbody.all(by.tagName("tr")).first();
        table.item_name1 = table.row.all(by.tagName('td')).get(table.titles_count).getText();
    }
    var showTitleList = function() {
        var thead;
        thead = element.all(by.css('div.ng-scope.DESC')).first();
        browser.actions().mouseMove(thead).perform();
        browser.actions().click(protractor.Button.RIGHT).perform();
    }
});
