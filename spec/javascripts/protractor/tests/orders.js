describe('Orders:',function() {

    describe('List:',function() {
        beforeEach(function() {
            element.all(by.cssContainingText('.top-nav-bar a','Orders')).first().click();
        });
        it('Url should match awaiting list',function() {
            expect(browser.getLocationAbsUrl()).toMatch('/#/orders/awaiting/1');
        });

        describe('Title:',function() {
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
                element.all(by.repeater('field in theads')).getText().then (function(text) {
                    expect(text).toContain('Email');
                    // Remove the title from table header
                    elem.list_elements = element.all(by.repeater('field in options.all_fields'));
                    elem.list_elements.get(2).click();
                });
            });
        });

        describe('Select:',function() {
            var table = {};
            var edit = {};
            var status = {};
            it('Right click on the Recipient makes the field editable for the order',function() {
                var table = {};
                var recipient = {};
                recipient.new = "Kalakar Sahoo";

                element.all(by.repeater('field in theads')).getText().then (function(text) {
                    var titles_count = text.indexOf('Recipient');

                    table.tbody = element.all(by.tagName("tbody")).first();
                    table.row = table.tbody.all(by.tagName("tr")).first();
                    table.row.all(by.tagName('td')).get(titles_count).then(function(td) {
                        recipient.actual = td.getText();
                        browser.actions().mouseMove(td).perform();
                        browser.actions().click(protractor.Button.RIGHT).perform().then(function() {
                            for (var i = 0; i<25; i++) {
                                browser.actions().sendKeys(protractor.Key.BACK_SPACE).perform();
                            }
                        });
                        browser.actions().sendKeys(recipient.new).perform();
                        table.exit_button = element(by.className("top-message"));
                        table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
                        expect(td.getText()).toContain(recipient.new);

                        table.tbody = element.all(by.tagName("tbody")).first();
                        table.row = table.tbody.all(by.tagName("tr")).first();
                        table.row.all(by.tagName('td')).get(titles_count).then(function(td) {
                            browser.actions().mouseMove(td).perform();
                            browser.actions().click(protractor.Button.RIGHT).perform().then(function() {
                                for (var i = 0; i<25; i++) {
                                    browser.actions().sendKeys(protractor.Key.BACK_SPACE).perform();
                                }
                            });
                            browser.actions().sendKeys(recipient.new).perform();

                            table.exit_button = element(by.className("top-message"));
                            table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
                        });
                    });
                });
            });
            it('Right click on the Status makes the field editable for the order',function() {
                status.value = "On Hold";

                element.all(by.repeater('field in theads')).getText().then (function(text) {
                    var titles_count_status = text.indexOf('Status');
                    var titles_count_order_number = text.indexOf('Order #')
                    table.tbody = element.all(by.tagName("tbody")).first();
                    table.row = table.tbody.all(by.tagName("tr")).first();
                    table.order_number = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();
                    table.row.all(by.tagName('td')).get(titles_count_status).then(function(td) {
                        browser.actions().mouseMove(td).perform();
                        browser.actions().click(protractor.Button.RIGHT).perform();
                        browser.actions().sendKeys(status.value).perform();

                        browser.executeScript('window.scrollTo(0,0);').then(function () {
                            element(by.cssContainingText('.panel-collapse.in .panel-body li','On Hold')).click();
                        });

                        table.tbody = element.all(by.tagName("tbody")).first();
                        table.row = table.tbody.all(by.tagName("tr")).first();
                        table.order_number1 = table.row.all(by.tagName('td')).get(titles_count_order_number).getText();
                        expect(table.order_number).toEqual(table.order_number1);
                    });
                });
            });
            it('Clicking on order number should open modal',function() {
                var panel = {};

                panel.panel_body = element.all(by.className('panel-body'));
                panel.panel_body_li = panel.panel_body.get(0).all(by.tagName("li"));
                panel.panel_body_li.get(1).click();

                new getFirstTableCell();

                table.column.element(by.tagName('a')).click();
                expect(browser.getLocationAbsUrl()).toContain('/#/orders/awaiting/1/');
                element(by.className("close-btn")).click();
            });
            it('Duplicates the selected order',function() {
                new selectFirstRowInList();
                element.all(by.repeater('field in theads')).getText().then (function(text) {
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
                table.order_number = table.column.getText();

                status.button = element.all(by.buttonText('Change Status')).first().click();
                status.parent = status.button.element(by.xpath(".."));
                status.ul = status.parent.element(by.tagName("ul"));
                status.li = status.ul.all(by.tagName("li")).get(1).click();

                element(by.cssContainingText('.panel-collapse.in .panel-body li','On Hold')).click();

                new getFirstTableCell();
                table.order_number1 = table.column.getText();
                expect(table.order_number).toContain(table.order_number1);
            });
            it('Deletes the selected order from the list',function() {
                new selectFirstRowInList();
                table.order_number = table.column.getText();

                edit.button = element.all(by.buttonText('Edit')).first().click();
                edit.parent = edit.button.element(by.xpath(".."));
                edit.ul = edit.parent.element(by.tagName("ul"));
                edit.li = edit.ul.all(by.tagName("li")).get(1).click();

                new getFirstTableCell();
                table.order_number1 = table.column.getText();

                expect(table.order_number1).not.toEqual(table.order_number);
            });
            var selectFirstRowInList = function() {
                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();
                table.row.click();
            }
            var getFirstTableCell = function() {
                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();
                table.column = table.row.all(by.tagName('td')).first();
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
