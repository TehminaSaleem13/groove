(function($){
    $.widget("suwala.doubleScroll", {
      options: {
        contentElement: undefined, // Widest element, if not specified first child element will be used
        topScrollBarMarkup: '<div class="suwala-doubleScroll-scroll-wrapper container-fluid" style="height: 20px;"><div class="suwala-doubleScroll-scroll col-xs-12" style="height: 20px;"></div></div>',
        topScrollBarInnerSelector: '.suwala-doubleScroll-scroll',     
        scrollCss: {                
          'overflow-x': 'scroll',
          'overflow-y':'hidden'
              },
        contentCss: {
          'overflow-x': 'scroll',
          'overflow-y':'hidden'
        },
        cols: 10,
        remove: false
      },    
      _create : function() {
        
        if(this.options.remove){
          $('.suwala-doubleScroll-scroll-wrapper').remove();
          return;
        }

        var self = this;
        var contentElement;

        //Clear if already present;
        $('.suwala-doubleScroll-scroll-wrapper').remove();

        // add div that will act as an upper scroll
        var topScrollBar = $($(self.options.topScrollBarMarkup));
        self.element.before(topScrollBar);

        // find the content element (should be the widest one)      
        if (self.options.contentElement !== undefined && self.element.find(self.options.contentElement).length !== 0) {
            contentElement = self.element.find(self.options.contentElement);
        }
        else {
            contentElement = self.element.find('>:first-child');
        }

        // bind upper scroll to bottom scroll
        topScrollBar.scroll(function(){
            self.element.scrollLeft(topScrollBar.scrollLeft());
        });

        // bind bottom scroll to upper scroll
        self.element.scroll(function(){
            topScrollBar.scrollLeft(self.element.scrollLeft());
        });

        // apply css
        topScrollBar.css(self.options.scrollCss);
        self.element.css(self.options.contentCss);

        // set the width of the wrappers
        $(self.options.topScrollBarInnerSelector).width(self.options.cols * 25 + 'rem');
        topScrollBar.width(self.element.innerWidth());
      }
    }
  );
})(jQuery);
