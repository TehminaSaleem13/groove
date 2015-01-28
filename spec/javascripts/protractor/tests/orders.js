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
                // return new showTitleList();
                console.log("printed................");
                elem.list_elements = element.all(by.repeater('field in options.all_fields'));
                elem.list_elements.get(2).click();
            });
            it('Right click on the Recipient makes the field editable for the order',function() {
                var table = {};
                var recipient = {};
                recipient.name = "Kalakar Sahoo";
                table.tbodies = element.all(by.tagName("tbody"));
                table.tbody = table.tbodies.first();
                table.rows = table.tbody.all(by.tagName("tr"));
                table.columns = table.rows.get(0).all(by.tagName('td'));
                table.recipient = table.columns.get(5);
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
            });
            it('Right click on the Status makes the field editable for the order',function() {
                var table = {};
                var status = {};
                status.value = "On Hold";
                table.tbodies = element.all(by.tagName("tbody"));
                table.tbody = table.tbodies.first();
                table.rows = table.tbody.all(by.tagName("tr"));
                table.columns = table.rows.get(0).all(by.tagName('td'));
                table.status = table.columns.get(6);
                table.order_number = table.columns.get(0).getText();
                browser.actions().mouseMove(table.status).perform();
                browser.actions().click(protractor.Button.RIGHT).perform();
                browser.actions().sendKeys(status.value).perform();

                table.panel_body = element.all(by.className('panel-body'));
                table.panel_body_li = table.panel_body.get(0).all(by.tagName("li"));
                browser.actions().mouseMove(table.panel_body_li.get(2)).perform();
                // browser.actions().click().perform();
                table.panel_body_li.get(2).click();

                table.tbodies = element.all(by.tagName("tbody"));
                table.tbody = table.tbodies.first();
                table.rows = table.tbody.all(by.tagName("tr"));
                table.columns = table.rows.get(0).all(by.tagName('td'));
                table.order_number1 = table.columns.get(0).getText();
                expect(table.order_number).toContain(table.order_number1);
            });
            it('Clicking on order number should open modal',function() {
                var table = {};

                table.tbodies = element.all(by.tagName("tbody"));
                table.tbody = table.tbodies.first();
                table.rows = table.tbody.all(by.tagName("tr"));
                table.columns = table.rows.get(0).all(by.tagName('td'));
                table.order_number = table.columns.get(0);
                table.order_number.all(by.tagName('a')).first().click();
                expect(browser.getLocationAbsUrl()).toContain('/#/orders/awaiting/1/');
            });
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
});
