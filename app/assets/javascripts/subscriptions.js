var subscription;

jQuery(function() {
  Stripe.setPublishableKey($('meta[name="stripe-key"]').attr('content'));
  return subscription.setupForm();
});

subscription = {
  setupForm: function() {
    return $('#subscription').submit(function(event) {
      event.preventDefault();
      console.log('processing card');
      $('input[type=submit]').attr('disabled', true);
      if ($('#number').length) {
        subscription.processCard();
        return false;
      } else {
        return true;
      }
    });
  },
  processCard: function() {
    var card;    
    card = {
      number: $('#number').val(),
      cvc: $('#cvc').val(),
      expMonth: $('#exp-month').val(),
      expYear: $('#exp-year').val()
    };
    return Stripe.createToken(card, subscription.handleStripeResponse);
  },
  handleStripeResponse: function(status, response) {
    if (status === 200) {
      $('#subscription_stripe_card_token').val(response.id);
      $.ajax({
        type: "PUT",
        contentType: "application/json; charset=utf-8",
        url: "/subscriptions/confirm_payment",
        data: JSON.stringify({ stripe_customer_token: response.id, id: $('#subscription_id').val() }),
        dataType: "json"
        
        }).success(function(response) {
          if (response.valid)
            window.location.href = 'https://local.groovepacker.com:3001/subscriptions/show/' + $('#subscription_id').val() + '?notice=Thank+you+for+your+subscription%21';
          else
            window.location.href = 'https://local.groovepacker.com:3001/subscriptions/select_plan'
          end
        });
    } else {
    alert('error');
      $('#stripe_error').text(response.error.message);
      return $('input[type=submit]').attr('disabled', false);
    }
  }
};
