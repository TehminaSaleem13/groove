var subscription;

jQuery(function() {
  Stripe.setPublishableKey($('meta[name="stripe-key"]').attr('content'));
  return subscription.setupForm();
});

subscription = {
  setupForm: function() {
    return $('#subscription').submit(function() {
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
    alert("processing")    
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
      alert("entering ajax.");
      $.ajax({
        type: "PUT",
        url: "/subscriptions/confirm_payment",
        data: { stripe_customer_token: response.id, id: $('#subscription_id').val() }
        });
      alert("exiting ajax.");
      $('#subscription')[0].submit();
    } else {
    alert('error');
      $('#stripe_error').text(response.error.message);
      return $('input[type=submit]').attr('disabled', false);
    }
  }
};
