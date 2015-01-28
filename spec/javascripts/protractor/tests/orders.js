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
        it('Right click on header should show list of headers',function() {
            var thead;
            var elem = {};
            thead = element.all(by.css('div.ng-scope.DESC')).first();
            browser.actions()
                .mouseMove(thead)
                .click(protractor.Button.RIGHT)
                .perform();
                
            elem.list_element = element(by.repeater('field in options.all_fields'));
            elem.parent1 = elem.list_element.element(by.xpath(".."));
            expect(elem.parent1.element(by.xpath("..")).getAttribute("class")).toEqual("clearfix open");
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
    });
});
