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
                return new showTitleList();
                elem.list_element = element(by.repeater('field in options.all_fields'));
                elem.parent1 = elem.list_element.element(by.xpath(".."));
                expect(elem.parent1.element(by.xpath("..")).getAttribute("class")).toEqual("clearfix open");
            });
            it('Click on a title in the list to view it in the table',function() {
                var elem = {};
                elem.list_elements = element.all(by.repeater('field in options.all_fields'));
                elem.list_elements.get(2).click();
                var titles = element.all(by.css('div.ng-scope.DESC'));
                expect(titles.get(11).getText()).toEqual('Email');

                // Remove the title from table header
                elem.list_elements = element.all(by.repeater('field in options.all_fields'));
                elem.list_elements.get(2).click();
            });
        });

        describe('Select:',function() {
            var table = {};
            var edit = {};
            var status = {};
            it('Right click on the Recipient makes the field editable for the order',function() {
                var table = {};
                var recipient = {};
                recipient.name = "Kalakar Sahoo";
                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();
                table.columns = table.row.all(by.tagName('td'));
                table.recipient = table.columns.get(5);
                recipient.name_actual = table.recipient.getText();
                browser.actions().mouseMove(table.recipient).perform();
                browser.actions().click(protractor.Button.RIGHT).perform().then(function() {
                    for (var i = 0; i < 30; i++) {
                        browser.actions().sendKeys(protractor.Key.BACK_SPACE).perform();
                    }
                });
                browser.actions().sendKeys(recipient.name).perform();
                table.exit_button = element(by.className("top-message"));
                table.exit_button.element(by.buttonText('Exit Edit Mode')).click();
                expect(table.recipient.getText()).toContain(recipient.name);

                // Set the recipient name to the original name
                browser.actions().mouseMove(table.recipient).perform();
                browser.actions().click(protractor.Button.RIGHT).perform().then(function() {
                    for (var i = 0; i < 30; i++) {
                        browser.actions().sendKeys(protractor.Key.BACK_SPACE).perform();
                    }
                });
                browser.actions().sendKeys(recipient.name_actual).perform();
            });
            it('Right click on the Status makes the field editable for the order',function() {
                status.value = "On Hold";
                table.tbody = element.all(by.tagName("tbody")).first();
                table.row = table.tbody.all(by.tagName("tr")).first();
                table.columns = table.row.all(by.tagName('td'));
                table.status = table.columns.get(6);
                table.order_number = table.columns.get(0).getText();
                browser.actions().mouseMove(table.status).perform();
                browser.actions().click(protractor.Button.RIGHT).perform();
                browser.actions().sendKeys(status.value).perform();

                browser.executeScript('window.scrollTo(0,0);').then(function () {
                    new clickOnHold();
                })
                
                new getFirstTableCell();
                table.order_number1 = table.columns.get(0).getText();
                expect(table.order_number).toContain(table.order_number1);
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
                table.order_number = table.column.getText();

                edit.button = element.all(by.buttonText('Edit')).first().click();
                edit.parent = edit.button.element(by.xpath(".."));
                edit.ul = edit.parent.element(by.tagName("ul"));
                edit.li = edit.ul.all(by.tagName("li")).get(2).click();

                new getFirstTableCell();
                table.order_number_duplicate = table.column.getText();
                expect(table.order_number_duplicate).toContain("duplicate");
            });
            it('Modifies the status of selected order',function() {
                new selectFirstRowInList();
                table.order_number = table.column.getText();

                status.button = element.all(by.buttonText('Change Status')).first().click();
                status.parent = status.button.element(by.xpath(".."));
                status.ul = status.parent.element(by.tagName("ul"));
                status.li = status.ul.all(by.tagName("li")).get(1).click();

                new clickOnHold();

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
                new getFirstTableCell();
                table.column.click();
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
            browser.actions()
                .mouseMove(thead)
                .click(protractor.Button.RIGHT)
                .perform();
        }
        var clickOnHold = function() {
            var panel = {};
            panel.panel_body = element.all(by.className('panel-body'));
            panel.panel_body_li = panel.panel_body.get(0).all(by.tagName("li"));
            panel.panel_body_span = panel.panel_body_li.get(2).all(by.tagName("span")).first();
            browser.actions().mouseMove(panel.panel_body_span).perform();
            browser.actions().click().perform();
        }
    });
});
