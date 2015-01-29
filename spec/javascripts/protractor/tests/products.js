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
        });

    });
    
    describe('Title:',function() {
        it('Right click on header should show list of titles',function() {
            var elem = {};
            new showTitleList();
            elem.list_element = element.all(by.repeater('field in options.all_fields')).first();
            elem.parent1 = elem.list_element.element(by.xpath(".."));
            expect(elem.parent1.element(by.xpath("..")).getAttribute("class")).toEqual("clearfix open");
        });
        it('Click on a title in the list to view it in the table',function() {
            var elem = {};
            elem.list_elements = element.all(by.repeater('field in options.all_fields'));
            elem.list_elements.get(6).click();
            var titles = element.all(by.css('div.ng-scope.DESC'));
            expect(titles.get(8).getText()).toEqual('Tertiary Location');

            // Remove the title from table header
            elem.list_elements = element.all(by.repeater('field in options.all_fields'));
            elem.list_elements.get(6).click();
        });
    });
    describe('Select:',function() {
        var table = {};
        var edit = {};
        var status = {};
        // it('Right click on the Barcode makes the field editable for the product',function() {
        //     var barcode = {};
        //     var column_no = 0;
        //     barcode.new = "BARCODE";
        //     table.thead = element.all(by.tagName("thead")).first();
        //     table.tr = table.thead.all(by.tagName("tr")).first();
        //     // console.log("text:");
        //     table.ths = table.tr.all(by.tagName("th")).getText();
        //     // .then (function(text) {
        //     //     console.log(text);
        //     //     console.log(text.length);
        //     //     console.log(text[5]);
        //     //     var column_count = text.length;
        //     //     var flag = false;
        //     //     for(var i=0; i<=text.length; i++) {
        //     //         console.log("index:");
                    
        //     //         if(String(text[i])=="Barcode") {
        //     //             console.log("in if");
        //     //             column_no = i;
        //     //             flag = true;
        //     //         }
        //     //         if(flag) break;
        //     //     }
        //     //     if(column_no == 7) {
        //     //         console.log("true...");
        //     //         // console.log(column_no);
        //     //     }
        //     // });
        //     column_no = table.ths.length.then (function(text) {
        //         console.log("text:");
        //         console.log(text);
        //     });
        //     if(table.ths.length == 8) {
        //         console.log("true...true");
        //         // console.log(column_no);
        //     }
        //     console.log("printed");
           
        //     // table.tbody = element.all(by.tagName("tbody")).first();
        //     // table.row = table.tbody.all(by.tagName("tr")).first();
        //     // table.columns = table.row.all(by.tagName('td'));
        //     // table.barcode = table.columns.get(column_no);
        //     // barcode.actual = table.barcode.getText();
        //     // browser.actions().mouseMove(table.barcode).perform();
        //     // browser.actions().click(protractor.Button.RIGHT).perform().then(function() {
        //     //     for (var i = 0; i < 30; i++) {
        //     //         browser.actions().sendKeys(protractor.Key.BACK_SPACE).perform();
        //     //     }
        //     // });
        //     // browser.actions().sendKeys(barcode.new).perform();
        //     // table.exit_button = element(by.className("top-message"));
        //     // table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
        //     // expect(table.barcode.getText()).toContain(barcode.new);
        // });
        it('Duplicates the selected order item',function() {
            new showTitleList();
            new selectFirstRowInList();
            table.item_name = element.all(by.css("td.ng-scope")).first().getText();

            edit.button = element.all(by.buttonText('Edit')).first().click();
            edit.parent = edit.button.element(by.xpath(".."));
            edit.ul = edit.parent.element(by.tagName("ul"));
            edit.li = edit.ul.all(by.tagName("li")).get(1).click();

            table.item_name1 = element.all(by.css("td.ng-scope")).first().getText();
            expect(table.item_name1).toContain(table.item_name);
        });
        it('Modifies the status of selected order item',function() {
            new selectFirstRowInList();
            table.item_name = element.all(by.css("td.ng-scope")).first().getText();
            status.button = element.all(by.buttonText('Change Status')).first().click();
            status.parent = status.button.element(by.xpath(".."));
            status.ul = status.parent.element(by.tagName("ul"));
            status.li = status.ul.all(by.tagName("li")).get(1).click();
            new clickActiveProducts();
            table.item_name1 = element.all(by.css("td.ng-scope")).first().getText();
            expect(table.order_number).toEqual(table.order_number1);
        });
        it('Deletes the selected order item',function() {
            new selectFirstRowInList();
            table.item_name = element.all(by.css("td.ng-scope")).first().getText();

            edit.button = element.all(by.buttonText('Edit')).first().click();
            edit.parent = edit.button.element(by.xpath(".."));
            edit.ul = edit.parent.element(by.tagName("ul"));
            edit.li = edit.ul.all(by.tagName("li")).get(0).click();

            table.item_name1 = element.all(by.css("td.ng-scope")).first().getText();

            expect(table.item_name1).not.toEqual(table.item_name);
        });
        var selectFirstRowInList = function() {
            new getFirstTableCell();
            table.column.click();
        }
        var getFirstTableCell = function() {
            table.tbody = element.all(by.tagName("tbody")).first();
            table.row = table.tbody.all(by.tagName("tr")).first();
            table.column = table.row.all(by.tagName('td')).first();
        }
        var clickActiveProducts = function() {
            var panel = {};
            panel.panel_body = element.all(by.className('panel-body'));
            panel.panel_body_li = panel.panel_body.get(0).all(by.tagName("li"));
            // panel.panel_body_span = panel.panel_body_li.get(3).all(by.tagName("span")).first();
            browser.actions().mouseMove(panel.panel_body_li.get(3)).perform();
            browser.actions().click().perform();
        }
    });
    var showTitleList = function() {
        var thead;
        thead = element.all(by.css('div.ng-scope.DESC')).first();
        browser.actions()
            .mouseMove(thead)
            .click(protractor.Button.RIGHT)
            .perform();
    }
});
