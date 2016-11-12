$(document).ready(function(){
	$(".no_of_users").val(3);
	add_discount_if_billing_annually();
	$(".no_of_users_inc").click(function(){
		calculate("+");
	});
	$(".no_of_users_dec").click(function(){
		calculate("-");
	});

	$(".bill_annually").change(function(){
		add_discount_if_billing_annually();
	});

	function calculate(sign){
		var no_of_users = $('.no_of_users').val();
		var total_amount;
		no_of_users = parseInt(no_of_users);
		if(sign=="+") {
			no_of_users = no_of_users+1;
		} else {
			if(no_of_users>2) {
				no_of_users = no_of_users-1;
			}
		}
		$(".price_label").text(50*no_of_users);
		$(".discount_amount").text(5*no_of_users);
		$(".no_of_users_label").text(no_of_users);
		$(".no_of_users").val(no_of_users);
		add_discount_if_billing_annually();
	}

	function add_discount_if_billing_annually() {
		var no_of_users = $('.no_of_users').val();
		no_of_users = parseInt(no_of_users);
		var checked = $(".bill_annually:checked").length;
		var total_amount;
		if(checked>0) {
			$('.discount_section').removeClass("fade4");
			total_amount = (50*no_of_users)-(5*no_of_users);
		} else {
			$('.discount_section').addClass("fade4");
			total_amount = 50*no_of_users;
		}
		$(".total_amount").text(total_amount);
	}
	
});
