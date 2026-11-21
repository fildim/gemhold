class_name Shop
extends Node
## The one Google Play purchase: Remove ads (product REMOVE_ADS, a one-time item, €3.99 in the Play
## Console). Android Play build only (export feature "ads" and the GodotGooglePlayBilling plugin);
## everywhere else available() is false and Settings shows nothing.
##
## Owning it sets Prefs "no_ads", which Ads.enabled() reads. Purchases are queried again every time
## the game starts (and on Restore purchases), so a reinstall or a new phone gets it back. A purchase
## must be acknowledged within three days or Google refunds it, so every owned, unacknowledged
## purchase is acknowledged as soon as it is seen.

signal changed   # owned, price or busy state changed: Settings redraws its buttons

const REMOVE_ADS := "remove_ads"
const PRICE_FALLBACK := "€3.99"   # shown until Google Play tells the local price
const PLUGIN := "GodotGooglePlayBilling"
const CLIENT_SCRIPT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"
const PURCHASED := 1              # BillingClient.PurchaseState.PURCHASED
const PENDING := 2                # BillingClient.PurchaseState.PENDING

static var _node: Shop
static var price := ""            # the local price from Google Play, or "" until known
static var busy := false          # a purchase flow is open
static var note := ""             # the last thing to tell the player ("" for nothing)

var _client: Node


## True in the Android Play build with the billing plugin present.
static func available() -> bool:
	return OS.has_feature("ads") and Engine.has_singleton(PLUGIN)


static func owned() -> bool:
	return Prefs.get_value("no_ads", false)


static func price_text() -> String:
	return price if price != "" else PRICE_FALLBACK


## Called once from main.gd: connects to Google Play and restores what the player owns.
static func start(host: Node) -> void:
	if _node != null or not available():
		return
	_node = Shop.new()
	_node.name = "Shop"
	host.add_child(_node)


static func node() -> Shop:
	return _node


## Opens Google Play's purchase sheet for Remove ads.
static func buy() -> void:
	if _node == null or busy or owned():
		return
	if _node._client == null or not _node._client.is_ready():
		note = "Google Play isn't reachable right now. Try again in a moment."
		if _node._client != null:
			_node._client.start_connection()
		_node.changed.emit()
		return
	busy = true
	note = ""
	var r: Dictionary = _node._client.purchase(REMOVE_ADS)
	if int(r.get("status", r.get("response_code", 0))) != 0:
		busy = false
		note = "The purchase couldn't start. Try again later."
	_node.changed.emit()


## Asks Google Play again what this account owns (the Restore purchases button).
static func restore() -> void:
	if _node == null:
		return
	note = "Checking your purchases…"
	_node._refresh()
	_node.changed.emit()


func _ready() -> void:
	var script: Script = load(CLIENT_SCRIPT)
	if script == null:
		return
	_client = script.new()
	add_child(_client)
	_client.connected.connect(_refresh)
	_client.connect_error.connect(func(_code: int, _msg: String) -> void:
		busy = false
		changed.emit())
	_client.query_purchases_response.connect(_on_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.query_product_details_response.connect(_on_details)
	_client.acknowledge_purchase_response.connect(func(_r: Dictionary) -> void: pass)
	_client.start_connection()


func _refresh() -> void:
	if _client == null:
		return
	if not _client.is_ready():
		_client.start_connection()   # connected fires _refresh again
		return
	_client.query_purchases(0)   # BillingClient.ProductType.INAPP
	_client.query_product_details(PackedStringArray([REMOVE_ADS]), 0)


static func _code(r: Dictionary) -> int:
	return int(r.get("response_code", r.get("status_code", 0)))


func _on_purchases(r: Dictionary) -> void:
	if _code(r) != 0:
		if note == "Checking your purchases…":
			note = "Google Play isn't reachable right now. Try again in a moment."
		changed.emit()
		return
	var had := owned()
	_take(r.get("purchases", []))
	if note == "Checking your purchases…":
		note = "Ads are removed: thank you!" if owned() else "No purchases found on this Google account."
	if owned() != had or note != "":
		changed.emit()


func _on_purchase_updated(r: Dictionary) -> void:
	busy = false
	var code := _code(r)
	if code == 0:
		_take(r.get("purchases", []))
		if owned():
			note = "Ads are removed: thank you!"
	elif code == 1:   # the player closed the sheet
		note = ""
	elif code == 7:   # already owned: restore it
		note = "You already own this. Restoring it…"
		_refresh()
	else:
		note = "The purchase didn't go through. Nothing was charged."
	changed.emit()


func _on_details(r: Dictionary) -> void:
	if _code(r) != 0:
		return
	for d: Dictionary in r.get("product_details", []):
		if d.get("product_id", "") != REMOVE_ADS:
			continue
		var offers: Array = d.get("one_time_purchase_offer_details_list", [])
		if offers.is_empty() and d.has("one_time_purchase_offer_details"):
			offers = [d["one_time_purchase_offer_details"]]
		if not offers.is_empty():
			price = String((offers[0] as Dictionary).get("formatted_price", ""))
			changed.emit()


## Owned, completed purchases of Remove ads: keep the reward and acknowledge them.
func _take(purchases: Array) -> void:
	for p: Dictionary in purchases:
		var ids: Array = p.get("product_ids", [])
		if not ids.has(REMOVE_ADS):
			continue
		var state := int(p.get("purchase_state", 0))
		if state == PENDING:
			note = "Your payment is pending. Ads go away once it completes."
			continue
		if state != PURCHASED:
			continue
		Prefs.set_value("no_ads", true)
		if not p.get("is_acknowledged", false):
			_client.acknowledge_purchase(String(p.get("purchase_token", "")))
