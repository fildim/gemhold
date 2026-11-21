extends SceneTree
## The Remove ads purchase (scripts/core/shop.gd) without Google Play: a fake billing client stands in
## for the plugin. Owned purchases turn ads off and get acknowledged; pending, cancelled and other
## products do not; a restore with nothing owned says so.
## Run: godot --headless --script res://tests/shop_test.gd

var fails := 0


class FakeClient:
	extends Node
	var acked: Array = []
	func acknowledge_purchase(token: String) -> void:
		acked.append(token)
	func is_ready() -> bool:
		return true
	func query_purchases(_t: int) -> void:
		pass
	func query_product_details(_ids: PackedStringArray, _t: int) -> void:
		pass


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	var keep: bool = Prefs.get_value("no_ads", false)
	var shop := Shop.new()
	var fake := FakeClient.new()
	shop._client = fake
	Prefs.set_value("no_ads", false)
	_check(not Shop.available(), "no billing outside the Android Play build")

	shop._on_purchases({"response_code": 0, "purchases": [{"product_ids": ["other"], "purchase_state": 1, "purchase_token": "x"}]})
	_check(not Shop.owned(), "another product does not remove ads")
	shop._on_purchases({"response_code": 0, "purchases": [{"product_ids": ["remove_ads"], "purchase_state": 2, "purchase_token": "p"}]})
	_check(not Shop.owned() and Shop.note.begins_with("Your payment is pending"), "a pending payment waits")
	shop._on_purchase_updated({"response_code": 1})
	_check(not Shop.owned() and not Shop.busy, "cancelled: nothing changes")

	Shop.note = "Checking your purchases…"
	shop._on_purchases({"response_code": 0, "purchases": []})
	_check(Shop.note.begins_with("No purchases found"), "restore with nothing owned says so")

	shop._on_purchase_updated({"response_code": 0, "purchases": [{"product_ids": ["remove_ads"], "purchase_state": 1, "purchase_token": "t1", "is_acknowledged": false}]})
	_check(Shop.owned() and not Ads.enabled(), "bought: ads are off")
	_check(fake.acked == ["t1"], "the purchase is acknowledged: %s" % [fake.acked])
	shop._on_purchases({"response_code": 0, "purchases": [{"product_ids": ["remove_ads"], "purchase_state": 1, "purchase_token": "t1", "is_acknowledged": true}]})
	_check(fake.acked == ["t1"], "an acknowledged purchase is not acknowledged again")

	shop._on_details({"response_code": 0, "product_details": [{"product_id": "remove_ads", "one_time_purchase_offer_details_list": [{"formatted_price": "3,99 €"}]}]})
	_check(Shop.price_text() == "3,99 €", "the local price from Google Play: %s" % Shop.price_text())

	Prefs.set_value("no_ads", keep)
	fake.free()
	shop.free()
	print("shop_test: %s" % ("all passed" if fails == 0 else "%d failed" % fails))
	quit(0 if fails == 0 else 1)
