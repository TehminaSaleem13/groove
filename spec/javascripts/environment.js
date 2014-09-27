module.exports = {
    seleniumAddress: (process.env.SELENIUM_URL || 'http://localhost:4444/wd/hub'),
    capabilities: {
        'browserName':
            (process.env.TEST_BROWSER_NAME || 'chrome'),
        'version':
            (process.env.TEST_BROWSER_VERSION || 'ANY')
    },

    baseUrl:
        'http://' + (process.env.HTTP_HOST || 'localhost') +
        ':' + (process.env.HTTP_PORT || '4000')

};
