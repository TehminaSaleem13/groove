var env= require('../environment.js');
exports.config = {
    seleniumAddress: env.seleniumAddress,

    capabilities: env.capabilities,

    specs: ['tests/**/*.js'],

    baseUrl: env.baseUrl,

    onPrepare: function() {
        browser.driver.get(env.baseUrl + '/users/sign_in');

        browser.driver.findElement(by.id('user_username')).sendKeys('admin');
        browser.driver.findElement(by.id('user_password')).sendKeys('12345678');
        browser.driver.findElement(by.id('login_button')).click();

        browser.driver.wait(function() {
            return browser.driver.getCurrentUrl().then(function(url) {
                return /\/#\//.test(url);
            });
        });
    },

    jasmineNodeOpts: {
        showColors: true,
        defaultTimeoutInterval: 30000
    }
};
