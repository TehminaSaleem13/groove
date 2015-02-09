var env= require('../environment.js');
exports.config = {
    sauceUser: process.env.SAUCE_USERNAME || 'groovetech',
    sauceKey: process.env.SAUCE_ACCESS_KEY || '1f05e3d9-4eb7-456a-a710-364d27172713',
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
