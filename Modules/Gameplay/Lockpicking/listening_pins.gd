extends RefCounted
## Four contacts shared by the listening demo and the shipmaster’s door.

const CONTACTS := [0.22, 0.74, 0.39, 0.87]
const CONTACT_WIDTH := 0.065
const SET_TIME := 0.32

var seated := 0
var travel := 0.0
var contact := false
var listening := false
var settling := 0.0


func sweep(axis: float, delta: float) -> bool:
	travel = clampf(travel + axis * delta * 0.56, 0.0, 1.0)
	var touching := seated < CONTACTS.size() and absf(travel - CONTACTS[seated]) <= CONTACT_WIDTH
	var found := touching and not contact
	contact = touching
	return found


func listen(held: bool, delta: float) -> bool:
	if not listening:
		return false
	if not held or not contact:
		listening = false
		settling = 0.0
		return false
	settling += delta
	if settling < SET_TIME:
		return false
	seated += 1
	release()
	return true


func release() -> void:
	contact = false
	listening = false
	settling = 0.0
