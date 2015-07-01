var env= require('../environment.js');
exports.config = {
    sauceUser: process.env.SAUCE_USERNAME || 'sahoonavaratan',
    sauceKey: process.env.SAUCE_ACCESS_KEY || 'c8da938f-2661-4ff0-8507-78e3c905995a',
    // seleniumAddress: env.seleniumAddress,

    capabilities: env.capabilities,

    specs: ['tests/**/*.js'],

    baseUrl: env.baseUrl,

    onPrepare: function() {
        require('jasmine-reporters');
        browser.driver.manage().window().maximize();
        browser.driver.get(env.baseUrl + '/users/sign_in');

        browser.driver.findElement(by.id('user_username')).sendKeys('admin');
        browser.driver.findElement(by.id('user_password')).sendKeys('12345678');
        browser.driver.findElement(by.id('login_button')).click();

        browser.driver.wait(function() {
            return browser.driver.getCurrentUrl().then(function(url) {
                return /\/#\//.test(url);
            });
        });
        jasmine.getEnv().addReporter(new jasmine.JUnitXmlReporter('protractor_report', true, true));
    },

    jasmineNodeOpts: {
        showColors: true,
        isVerbose:true,
        defaultTimeoutInterval: 150000
    }
};
