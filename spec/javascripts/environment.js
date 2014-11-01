module.exports = {
    seleniumAddress: (process.env.SELENIUM_URL || 'http://localhost:4444/wd/hub'),
    capabilities: {
        'browserName':
            (process.env.TEST_BROWSER_NAME || 'chrome'),
        'version':
            (process.env.TEST_BROWSER_VERSION || 'ANY')
    },

    baseUrl:
        'http://' + (process.env.HTTP_HOST || 'test.testpacker.com') +
        (process.env.HTTP_PORT ? ':'+ process.env.HTTP_PORT : '')

};
