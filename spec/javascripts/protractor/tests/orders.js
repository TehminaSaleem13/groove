describe('Orders:',function() {

    describe('List:',function() {
        beforeEach(function() {
            element.all(by.cssContainingText('.top-nav-bar a','Orders')).first().click();
        });
        it('Url should match awaiting list',function() {
            expect(browser.getLocationAbsUrl()).toMatch('/#/orders/awaiting/1');
        });

        describe('Title:',function() {
            var table = {};
            it('First title should be orders',function() {
                expect(element.all(by.css('.panel-title')).first().getText()).toEqual('Orders');
            });
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
                elem.list_elements.get(2).click();
                table.list_table = element.all(by.tagName('table')).first();
                table.thead = table.list_table.element(by.tagName('thead'));
                table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                    expect(text).toContain('Email');
                    // Remove the title from table header
                    elem.list_elements = element.all(by.repeater('field in options.all_fields'));
                    elem.list_elements.get(2).click();
                    new showTitleList();
                });
            });
        });

        describe('Select:',function() {
            var table = {};
            var edit = {};
            var status = {};
            // it('Right click on the Recipient makes the field editable for the order',function() {
            //     var table = {};
            //     var recipient = {};
            //     recipient.new = "Kalakar Sahoo";

            //     element.all(by.repeater('field in theads')).getText().then (function(text) {
            //         var titles_count = text.indexOf('Recipient');

            //         table.tbody = element.all(by.tagName("tbody")).first();
            //         table.row = table.tbody.all(by.tagName("tr")).first();
            //         recipient.actual = table.row.all(by.tagName('td')).get(titles_count).all(by.tagName('div')).first().getText();
            //         table.row.all(by.tagName('td')).get(titles_count).all(by.tagName('div')).first().all(by.tagName('div')).last().then(function(td) {
            //             browser.actions().mouseMove(td).perform();
            //             browser.actions().click(protractor.Button.RIGHT).perform().then(function() {
            //                 for (var i = 0; i<25; i++) {
            //                     browser.actions().sendKeys(protractor.Key.BACK_SPACE).perform();
            //                 }
            //                 browser.actions().sendKeys(recipient.new).perform().then(function() {
            //                     table.exit_button = element(by.className("top-message"));
            //                     table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
            //                     expect(table.row.all(by.tagName('td')).get(titles_count).all(by.tagName('div')).first().getText()).toContain(recipient.new);
            //                 });
            //                 table.tbody = element.all(by.tagName("tbody")).first();
            //                 table.row = table.tbody.all(by.tagName("tr")).first();
            //                 table.row.all(by.tagName('td')).get(titles_count).all(by.tagName('div')).first().all(by.tagName('div')).last().then(function(td) {
            //                     browser.actions().mouseMove(td).perform();
            //                     browser.actions().click(protractor.Button.RIGHT).perform().then(function() {
            //                         for (var i = 0; i<25; i++) {
            //                             browser.actions().sendKeys(protractor.Key.BACK_SPACE).perform();
            //                         }
            //                         browser.actions().sendKeys(recipient.actual).perform().then(function() {
            //                             table.exit_button = element(by.className("top-message"));
            //                             table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
            //                         });
            //                     });
            //                 });
            //             });
            //         });
            //     });
            // });
            // it('Right click on the Status makes the field editable for the order',function() {
            //     status.value = "On Hold";

            //     element.all(by.repeater('field in theads')).getText().then (function(text) {
            //         var titles_count_status = text.indexOf('Status');
            //         var titles_count_order_number = text.indexOf('Order #')
            //         table.tbody = element.all(by.tagName("tbody")).first();
            //         table.row = table.tbody.all(by.tagName("tr")).first();
            //         table.order_number = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();
            //         table.row.all(by.tagName('td')).get(titles_count_status).then(function(td) {
            //             browser.actions().mouseMove(td.all(by.tagName('div')).first()).perform();
            //             browser.actions().click(protractor.Button.RIGHT).perform();
            //             // browser.actions().click(protractor.Button.RIGHT).perform();
            //             // browser.actions().click().perform();
            //             browser.sleep(1000);
            //             // td.element(by.cssContainingText('.ng-scope .ng-binding.ng-scope .ng-isolate-scope.ng-pristine.ng-valid .ng-scope .tag-bubble.false-tag-bubble.input-text .span3.ng-pristine.ng-valid option','On HOld')).click();
            //             // browser.actions().sendKeys(status.value).perform();
            //             browser.actions().sendKeys(protractor.Key.ARROW_DOWN).perform();
            //             // table.exit_button = element(by.className("top-message"));
            //             // table.exit_button.element(by.buttonText('Exit Edit Mode')).click();

            //             browser.executeScript('window.scrollTo(0,0);').then(function () {
            //                 // table.exit_button = element(by.className("top-message"));
            //                 // table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
            //                 element(by.cssContainingText('.panel-collapse.in .panel-body li','On Hold')).click();
            //                 table.tbody = element.all(by.tagName("tbody")).first();
            //                 table.row = table.tbody.all(by.tagName("tr")).first();
            //                 table.order_number1 = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();
            //                 expect(table.order_number).toEqual(table.order_number1);
            //             });
            //         });
            //     });
            // });
            it('Duplicates the selected order',function() {
                new selectFirstRowInList();
                table.list_table = element.all(by.tagName('table')).first();
                table.thead = table.list_table.element(by.tagName('thead'));
                table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                    var titles_count_order_number = text.indexOf('Order #')
                    table.tbody = element.all(by.tagName("tbody")).first();
                    table.row = table.tbody.all(by.tagName("tr")).first();
                    table.order_number = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();

                    edit.button = element.all(by.buttonText('Edit')).first().click();
                    edit.parent = edit.button.element(by.xpath(".."));
                    edit.ul = edit.parent.element(by.tagName("ul"));
                    edit.li = edit.ul.all(by.tagName("li")).get(2).click();

                    table.tbody = element.all(by.tagName("tbody")).first();
                    table.row = table.tbody.all(by.tagName("tr")).first();
                    table.order_number1 = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();
                    expect(table.order_number1).toContain(table.order_number);
                });
            });
            it('Modifies the status of selected order',function() {
                new selectFirstRowInList();
                table.list_table = element.all(by.tagName('table')).first();
                table.thead = table.list_table.element(by.tagName('thead'));
                table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                    var titles_count_order_number = text.indexOf('Order #')
                    table.tbody = element.all(by.tagName("tbody")).first();
                    table.row = table.tbody.all(by.tagName("tr")).first();
                    table.order_number = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();
                    
                    status.button = element.all(by.buttonText('Change Status')).first().click();
                    status.parent = status.button.element(by.xpath(".."));
                    status.ul = status.parent.element(by.tagName("ul"));
                    status.li = status.ul.all(by.tagName("li")).get(1).click();
                    element(by.cssContainingText('.panel-collapse.in .panel-body li','On Hold')).click();

                    table.tbody = element.all(by.tagName("tbody")).first();
                    table.row = table.tbody.all(by.tagName("tr")).first();
                    table.order_number1 = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();
                    expect(table.order_number).toEqual(table.order_number1);
                });
            });
            it('Deletes the selected order from the list',function() {
                new selectFirstRowInList();
                table.list_table = element.all(by.tagName('table')).first();
                table.thead = table.list_table.element(by.tagName('thead'));
                table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                    var titles_count_order_number = text.indexOf('Order #')
                    table.tbody = element.all(by.tagName("tbody")).first();
                    table.row = table.tbody.all(by.tagName("tr")).first();
                    table.order_number = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();
                    
                    edit.button = element.all(by.buttonText('Edit')).first().click();
                    edit.parent = edit.button.element(by.xpath(".."));
                    edit.ul = edit.parent.element(by.tagName("ul"));
                    edit.li = edit.ul.all(by.tagName("li")).get(1).click();

                    table.tbody = element.all(by.tagName("tbody")).first();
                    table.row = table.tbody.all(by.tagName("tr")).first();
                    table.order_number1 = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();
                    expect(table.order_number).not.toEqual(table.order_number1);
                });
            });
            it('Clicking on order number should open modal',function() {
                element(by.cssContainingText('.panel-collapse.in .panel-body li','Awaiting')).click();
                table.list_table = element.all(by.tagName('table')).first();
                table.thead = table.list_table.element(by.tagName('thead'));
                table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                    new openOrderModal(text);
                    
                    expect(browser.getLocationAbsUrl()).toContain('/#/orders/awaiting/1/');
                    element(by.className("close-btn")).click();
                });
            });
            
            describe('Modal:',function() {
                var order = {};
                it('asserts the information in Order modal',function() {
                    table.list_table = element.all(by.tagName('table')).first();
                    table.thead = table.list_table.element(by.tagName('thead'));
                    table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                        new openOrderModal(text);
                        order.first_field_set = element.all(by.tagName('fieldset')).get(0);

                        order.first_name_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'First Name'));
                        order.first_name_div = order.first_name_label.element(by.xpath('..'));
                        order.first_name_value = order.first_name_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.first_name_value).toEqual(element(by.model('orders.single.basicinfo.firstname')).getAttribute('value'));

                        order.last_name_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'Last Name'));
                        order.last_name_div = order.last_name_label.element(by.xpath('..'));
                        order.last_name_value = order.last_name_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.last_name_value).toEqual(element(by.model('orders.single.basicinfo.lastname')).getAttribute('value'));

                        order.company_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'Company'));
                        order.company_div = order.company_label.element(by.xpath('..'));
                        order.company_value = order.company_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.company_value).toEqual(element(by.model('orders.single.basicinfo.company')).getAttribute('value'));

                        order.address1_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'Address line 1'));
                        order.address1_div = order.address1_label.element(by.xpath('..'));
                        order.address1_value = order.address1_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.address1_value).toEqual(element(by.model('orders.single.basicinfo.address_1')).getAttribute('value'));

                        order.address2_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'Address line 2'));
                        order.address2_div = order.address2_label.element(by.xpath('..'));
                        order.address2_value = order.address2_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.address2_value).toEqual(element(by.model('orders.single.basicinfo.address_2')).getAttribute('value'));

                        order.city_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'City'));
                        order.city_div = order.city_label.element(by.xpath('..'));
                        order.city_value = order.city_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.city_value).toEqual(element(by.model('orders.single.basicinfo.city')).getAttribute('value'));

                        order.state_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'State'));
                        order.state_div = order.state_label.element(by.xpath('..'));
                        order.state_value = order.state_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.state_value).toEqual(element(by.model('orders.single.basicinfo.state')).getAttribute('value'));

                        order.increment_id_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'Order #'));
                        order.increment_id_div = order.increment_id_label.element(by.xpath('..'));
                        order.increment_id_value = order.increment_id_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.increment_id_value).toEqual(element(by.model('orders.single.basicinfo.increment_id')).getAttribute('value'));

                        order.email_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'Buyer Email'));
                        order.email_div = order.email_label.element(by.xpath('..'));
                        order.email_value = order.email_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.email_value).toEqual(element(by.model('orders.single.basicinfo.email')).getAttribute('value'));

                        order.store_order_id_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'Store Order id'));
                        order.store_order_id_div = order.store_order_id_label.element(by.xpath('..'));
                        order.store_order_id_value = order.store_order_id_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.store_order_id_value).toEqual(element(by.model('orders.single.basicinfo.store_order_id')).getAttribute('value'));

                        order.postcode_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'Zip'));
                        order.postcode_div = order.postcode_label.element(by.xpath('..'));
                        order.postcode_value = order.postcode_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.postcode_value).toEqual(element(by.model('orders.single.basicinfo.postcode')).getAttribute('value'));

                        order.country_label = order.first_field_set.element(by.cssContainingText('.row .container-fluid .form-group label', 'Country'));
                        order.country_div = order.country_label.element(by.xpath('..'));
                        order.country_value = order.country_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.country_value).toEqual(element(by.model('orders.single.basicinfo.country')).getAttribute('value'));

                        order.last_field_set = element.all(by.tagName('fieldset')).get(1);
                        order.scanned_on_label = order.last_field_set.element(by.cssContainingText('.row .form-group label', 'Scanned on'));
                        order.scanned_on_div = order.scanned_on_label.element(by.xpath('..'));
                        order.scanned_on_value = order.scanned_on_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.scanned_on_value).toEqual(element(by.model('orders.single.basicinfo.scanned_on')).getAttribute('value'));

                        order.tracking_num_label = order.last_field_set.element(by.cssContainingText('.row .form-group label', 'Tracking id #'));
                        order.tracking_num_div = order.tracking_num_label.element(by.xpath('..'));
                        order.tracking_num_value = order.tracking_num_div.element(by.tagName('input')).getAttribute('value');
                        expect(order.tracking_num_value).toEqual(element(by.model('orders.single.basicinfo.tracking_num')).getAttribute('value'));
                        element(by.className("close-btn")).click();
                    });
                    
                });
                it('asserts the items in Order modal',function() {
                    table.list_table = element.all(by.tagName('table')).first();
                    table.thead = table.list_table.element(by.tagName('thead'));
                    table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                        var titles_items_count = text.indexOf('Items');
                        new openOrderModal(text);
                        element(by.cssContainingText('.modal-body .tabbable .nav.nav-tabs.modal-nav.ng-isolate-scope .nav.nav-tabs li','Items')).all(by.tagName('a')).first().click();
                        browser.sleep(1000);
                        var row = element(by.className('tab-content'));
                        var table_pane = row.all(by.cssContainingText('.ng-isolate-scope .binder', 'Primary Image')).first().all(by.tagName('div')).get(1);

                        table_pane.all(by.repeater('field in theads')).getText().then (function(items_title) {
                            var total_qty_ordered = 0;
                            var total_qty;
                            var title_qty_ordered_count = items_title.indexOf('Qty Ordered');
                            var table_body = table_pane.all(by.tagName('tbody')).first();
                            table_body.all(by.tagName('tr')).then(function(trs) {
                                for(var i = 0; i<trs.length;i++) {
                                    total_qty = trs[i].all(by.tagName('td')).getText().then(function(tds) {
                                        return total_qty_ordered = String(Number(total_qty_ordered) + Number(tds[title_qty_ordered_count]));
                                    });
                                }
                                expect(table.items_count).toEqual(total_qty);
                            });
                        });
                        element(by.className("close-btn")).click();
                    });
                });
                it('\'Add Item\', adds an item to the existing items',function() {
                    table.list_table = element.all(by.tagName('table')).first();
                    table.thead = table.list_table.element(by.tagName('thead'));
                    table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                        var titles_items_count = text.indexOf('Items');
                        new openOrderModal(text);
                        element(by.cssContainingText('.modal-body .tabbable .nav.nav-tabs.modal-nav.ng-isolate-scope .nav.nav-tabs li','Items')).all(by.tagName('a')).first().click();
                        var row = element(by.className('tab-content'));
                        var table_pane = row.all(by.cssContainingText('.ng-isolate-scope .binder', 'Primary Image')).first().all(by.tagName('div')).get(1);
                        var table_body = table_pane.all(by.tagName('tbody')).first();
                        table_body.all(by.tagName('tr')).then(function(trs) {
                            table.row_count = trs.length;
                        });
                        row.all(by.cssContainingText('.btn-group.pull-right', 'Add Item')).first().all(by.tagName('button')).first().click();
                        var header = element.all(by.cssContainingText('.modal-dialog.modal-lg .modal-content .modal-header div','Select Product to ')).first();
                        var modal_header = header.element(by.xpath('..'));
                        var modal_scope = modal_header.element(by.xpath('..'));
                        var modal_body = modal_scope.element(by.className('modal-body'));
                        var modal_rows = modal_body.all(by.className('row'));
                        var status = false;
                        modal_rows.get(3).all(by.tagName('tbody')).first().all(by.tagName('tr')).getText().then(function(trs) {
                            for(i=0 ; i<trs.length ; i++) {
                                status =  function () {
                                    if(modal_rows.get(3).all(by.tagName('tbody')).first().all(by.tagName('tr')).get(i).all(by.tagName('td')).getText().get(2) == 'active') {
                                        status = true;
                                    }
                                    return status;
                                };
                                if(status) {
                                    modal_rows.get(3).all(by.tagName('tbody')).first().all(by.tagName('tr')).get(i).click();
                                    break;
                                }
                            }
                        });

                        modal_rows.get(2).element(by.cssContainingText('button','Save & Close')).click();
                        var row = element(by.className('tab-content'));
                        var table_pane = row.all(by.cssContainingText('.ng-isolate-scope .binder', 'Primary Image')).first().all(by.tagName('div')).get(1);
                        var table_body = table_pane.all(by.tagName('tbody')).first();
                        table_body.all(by.tagName('tr')).then(function(trs) {
                            table.row_count1 = trs.length;
                            expect(table.row_count1).toEqual(table.row_count + 1);
                        });
                        element(by.className("close-btn")).click();
                    });
                });
                it('\'Remove Selected Items\', removes items from the existing items list',function() {
                    // element(by.cssContainingText('.panel-collapse.in .panel-body li','On Hold')).click();
                    table.list_table = element.all(by.tagName('table')).first();
                    table.thead = table.list_table.element(by.tagName('thead'));
                    table.thead.all(by.repeater('field in theads')).getText().then (function(text) {
                        var titles_items_count = text.indexOf('Items');
                        new openOrderModal(text);
                        element(by.cssContainingText('.modal-body .tabbable .nav.nav-tabs.modal-nav.ng-isolate-scope .nav.nav-tabs li','Items')).all(by.tagName('a')).first().click();
                        var row = element(by.className('tab-content'));
                        var table_pane = row.all(by.cssContainingText('.ng-isolate-scope .binder', 'Primary Image')).first().all(by.tagName('div')).get(1);
                        var table_body = table_pane.all(by.tagName('tbody')).first();
                        table_body.all(by.tagName('tr')).then(function(trs) {
                            table.row_count = trs.length;
                        });
                        table_body.all(by.tagName('tr')).first().click();
                        row.all(by.cssContainingText('.btn-group.pull-right', 'Remove selected Items')).first().all(by.tagName('button')).last().click();
                        var row = element(by.className('tab-content'));
                        var table_pane = row.all(by.cssContainingText('.ng-isolate-scope .binder', 'Primary Image')).first().all(by.tagName('div')).get(1);
                        var table_body = table_pane.all(by.tagName('tbody')).first();
                        table_body.all(by.tagName('tr')).then(function(trs) {
                            table.row_count1 = trs.length;
                            expect(table.row_count1).toEqual(table.row_count - 1);
                        });
                        element(by.className("close-btn")).click();
                    });
                });
            });

            var selectFirstRowInList = function() {
                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();
                table.row.click();
            }

            var openOrderModal = function(text) {
                table.titles_count_order_number = text.indexOf('Order #');
                var titles_items_count = text.indexOf('Items');
                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();
                table.items_count = table.row.all(by.tagName('td')).get(titles_items_count).getText();
                table.row.all(by.tagName('td')).get(table.titles_count_order_number).all(by.tagName('a')).first().click();
            }
        });

        var showTitleList = function() {
            var thead;
            thead = element.all(by.css('div.ng-scope.DESC')).first();
            browser.actions().mouseMove(thead).perform();
            browser.actions().click(protractor.Button.RIGHT).perform();
        }
    });
});
