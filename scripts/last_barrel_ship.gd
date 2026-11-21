extends RefCounted
## The outbound ship is a longitudinal cutaway. The camera-facing bulwark stays low
## while the far side carries the full ceiling knees, hull ceiling and cabin windows.

const JOINERY := preload("res://scripts/last_barrel_ship_mesh.gd")
const LIGHTS := preload("res://scripts/last_barrel_lights.gd")
const BARREL := preload("res://Modules/Props/CargoBarrel.tscn")
const PLANKS := preload("res://Mesh/Harboretum-Mesh/wood_planks.tscn")
const PLANK_COLORS := ["oak", "oak_dark", "oak", "oak_light", "oak_red", "oak", "oak_red"]
const POINTS := {
	"Boarding": Vector3(0.15, 0.49, -21), "CargoSlate": Vector3(2.85, 0.49, -22.75),
	"SailclothCrate": Vector3(8.4, -0.71, -23.35), "SilverCrate": Vector3(12.7, -0.71, -19.65),
	"CrescentCrate": Vector3(15.25, -0.71, -23.15), "StarboardLanding": Vector3(21.95, 1.14, -24.35),
	"Seal": Vector3(25.0, 1.14, -23.10),
}
const FAR := -25.65
const NEAR := -17.6
var j := JOINERY.new()
var kit


func build(outbound: Node3D, existing_kit) -> void:
	kit = existing_kit
	var shell := _group(outbound, "Hull")
	var deck := _group(outbound, "FreightDeck")
	var hold := _group(outbound, "LowerHold")
	var stairs := _group(outbound, "SternPassages")
	var cabin := _group(outbound, "PurserCabin")
	_hull(shell)
	_freight(deck)
	_hold(hold)
	_passages(stairs)
	_cabin(cabin)
	var gangway: Node3D = kit.visual(outbound, PLANKS, Vector3(6, 0, -14.4), Vector3(1.78, 0.22, 6.9), true)
	gangway.name = "PersonnelGangway"
	kit.box(gangway, Vector3(1.78, 0.22, 6.9), Vector3.DOWN * 0.11)
	var seal := preload("res://Modules/Gameplay/LastBarrel/night_seal.tscn").instantiate() as Area3D
	seal.name = "NightSeal"
	seal.position = Vector3(25.05, 0.65, -24.43)
	seal.hide()
	outbound.add_child(seal)
	j.finish()


func _group(parent: Node3D, title: String, at := Vector3.ZERO) -> Node3D:
	var result := Node3D.new()
	result.name = title
	result.position = at
	parent.add_child(result, true)
	return result


func _block(parent: Node3D, at: Vector3, size: Vector3, angle := 0.0) -> void:
	var collider := _group(parent, "Blocking", at)
	collider.rotation.z = angle
	kit.box(collider, size)


func _floor(parent: Node3D, title: String, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var section := _group(parent, title)
	var rows := ceili((z1-z0) / 0.40)
	var width := (z1-z0)/rows
	for row in rows:
		var x := x0
		var index := 0
		while x < x1 - 0.01:
			var length := minf(x1 - x, 1.18 + fmod(row * 1.23, 2.7) if index == 0 else 3.15 + fmod(row * 1.23 + index * 0.73, 1.25))
			var color_key: String = PLANK_COLORS[(row*3 + index*2) % PLANK_COLORS.size()]
			var z := z0 + width*(row + 0.5)
			j.box(section, color_key, Vector3(x + length/2, y - 0.115, z), Vector3(maxf(0.01, length - 0.016), 0.23, width - 0.014), Basis.IDENTITY, 0.01)
			if length > 1.0 and (row+index) % 3 == 0:
				for off in [-0.082, 0.082]:
					j.rod(section, "tar", Vector3(x + 0.105,y-0.004,z+off), Vector3(x + 0.105,y+0.003,z+off), 0.017, 0.017, 6)
			x += length
			index += 1
	_block(section, Vector3((x0+x1)/2, y - 0.12, (z0+z1)/2), Vector3(x1-x0, 0.24, z1-z0))


func _hull(root: Node3D) -> void:
	# The stem tapers beyond the usable foredeck. The transom carries the stern cabin.
	var xs := [-5.9,-4.4,-2.05,3.4,10.0,18.0,23.7,28.1,29.25]
	var ws := [0.08,2.36,4.0,4.24,4.35,4.34,4.20,4.05,3.03]
	var mid := (FAR + NEAR) * 0.5
	for index in xs.size()-1:
		var bay := _group(root, "ShellBay%02d" % index)
		for side: float in [-1.0,1.0]:
			var top0 := 0.43 if index < 3 else (-0.62 if index < 6 else 0.85)
			var top1 := 0.43 if index + 1 < 3 else (-0.62 if index + 1 < 6 else 0.85)
			for band in 6:
				var a := float(band)/6
				var b := float(band+1)/6
				var points := PackedVector3Array()
				for corner in [Vector2(index,a),Vector2(index+1,a),Vector2(index+1,b),Vector2(index,b)]:
					var k := int(corner.x)
					var w: float = ws[k] * (0.53 + 0.47 * sqrt(corner.y))
					points.append(Vector3(xs[k], lerpf(-2.65,top0 if k == index else top1,corner.y), mid + w * side))
				j.face(bay, ["tar","wainscot","oak_dark","blue","frame","oak_red"][band], points, Vector3(0,0.12,side))
				if band == 3 or band == 5:
					j.timber(bay,"brass" if band == 3 else "tar", points[2], points[3], 0.075, 0.10)
	# Cutwater, whitewater-free bow planking and a transom cap.
	for i in 7:
		var x := -5.6 + i * 0.5
		var width := clampf((x+6) * 2.4,0.2,7.95)
		j.box(root,PLANK_COLORS[i],Vector3(x,-0.11,mid),Vector3(0.48,0.21,width))
	j.timber(root, "frame", Vector3(-5.9,-1.9,mid), Vector3(-6.15,0.95,mid), 0.22,0.22)
	j.timber(root, "frame", Vector3(-5.7,0.65,mid),Vector3(-7.5,1.55,mid),0.16,0.16)
	_block(root,Vector3(-2.79,0.42,mid),Vector3(0.17,0.86,8.05))
	_block(root,Vector3(28.1,1.27,mid),Vector3(0.18,1.4,8.05))


func _rails(parent: Node3D, x0: float, x1: float, z: float, y: float, high: bool) -> void:
	var rail := _group(parent,"Bulwark")
	var h := 0.90 if high else 0.48
	var c := ceili((x1-x0)/1.55)
	j.box(rail,"blue",Vector3((x0+x1)/2,y+0.13,z),Vector3(x1-x0,0.26,0.16))
	j.box(rail,"oak_light",Vector3((x0+x1)/2,y+h,z),Vector3(x1-x0,0.112,0.18))
	for i in c+1:
		var x := lerpf(x0,x1,float(i)/c)
		j.box(rail,"frame",Vector3(x,y+h*0.5,z),Vector3(0.12,h,0.15))
		j.box(rail,"brass",Vector3(x,y+h-0.12,z),Vector3(0.13,0.045,0.16))
	_block(rail,Vector3((x0+x1)/2,y+0.50,z),Vector3(x1-x0,1.0,0.18))


func _stair(parent: Node3D, title: String, x0: float, x1: float, z: float, y0: float, y1: float, width: float) -> void:
	var stair := _group(parent, title)
	var count := ceili(absf(y1-y0) / 0.15)
	var run := (x1-x0)/count
	for i in count:
		var y := lerpf(y0,y1,(i + 0.5)/count)
		var x := x0 + (i+0.5)*run
		j.box(stair, PLANK_COLORS[i % 7], Vector3(x,y-0.09,z), Vector3(run-0.012,0.18,width))
		j.box(stair,"oak_light",Vector3(x + signf(y0-y1)*run*0.42,y-0.006,z),Vector3(0.045,0.04,width-0.02))
	for s: float in [-1.0,1.0]:
		j.timber(stair,"frame",Vector3(x0,y0-0.11,z+s*width/2),Vector3(x1,y1-0.11,z+s*width/2),0.24,0.14)
	var angle := atan2(y1-y0,x1-x0)
	var normal := Vector3(-sin(angle),cos(angle),0)
	_block(stair,Vector3((x0+x1)/2,(y0+y1)/2,z)-normal*0.115,Vector3(Vector2(x1-x0,y1-y0).length(),0.23,width+0.04),angle)


func _freight(deck: Node3D) -> void:
	_floor(deck,"ForedeckPlanking",-2.8,3.9,FAR,NEAR,0)
	# The stair occupies the full break in the deck. Raised hatch cheeks enclose its two sides.
	_floor(deck,"HatchStarboardWing",3.9,6.9,FAR,-23.0,0)
	_floor(deck,"HatchPortWing",3.9,6.9,-20.55,NEAR,0)
	_stair(deck,"FreightHatchCompanionway",3.9,6.9,-21.775,0,-1.20,2.45)
	for z in [-23.08,-20.47]:
		j.box(deck,"frame",Vector3(5.4,-0.13,z),Vector3(3.15,0.54,0.22))
		j.box(deck,"brass",Vector3(5.40,0.15,z),Vector3(3.16,0.035,0.13))
	for z in [-24.36,-19.05]:
		var length := 2.64 if z < -22.0 else 2.92
		j.box(deck,"blue",Vector3(6.85,-0.1,z),Vector3(0.22,1.92,length))
		j.box(deck,"oak_light",Vector3(6.85,0.88,z),Vector3(0.29,0.10,length))
		_block(deck,Vector3(6.85,-0.13,z),Vector3(0.26,2.30,length))
	_rails(deck,-2.75,6.87,FAR,0,true)
	_rails(deck,-2.75,6.87,NEAR,0,false)
	_cargo_slate(_group(deck,"CargoSlate",Vector3(2.62,0,-23.76)))
	_lantern(deck, "HatchLantern", Vector3(3.63, 1.18, -23.69), Vector3(2.85, 0.15, -22.95), 3.1, 38.0)
	_crate(deck,"DocksideStores",Vector3(-1.52,0,-24.26),1.18,0.91,0.98,"oak_red")
	_crate(deck,"DocksideStoresUpper",Vector3(-1.52,0.91,-24.26),0.90,0.66,0.76,"oak")
	_bale(deck,Vector3(5.10,0,-24.77),1.18)
	_davit(deck)
	_coil(deck,Vector3(-1.48,0.02,-22.42),0.36)
	var spill := _group(deck,"SpilledPotatoes",Vector3(0,0,-20.64))
	for i in 12:
		var off := Vector3(sin(i*7.2)*(0.22+i*0.055),0,cos(i*1.76)*(0.14+i*0.061))
		j.rod(spill,"cord_dark" if i % 3 else "cord",off+Vector3.UP*0.025,off+Vector3.UP*0.14,0.072+i%3*0.018,0.046,7)


func _davit(parent: Node3D) -> void:
	var rig := _group(parent,"ForemastAndTackle",Vector3(-1.28,0,-25.06))
	j.rod(rig,"oak_dark",Vector3.ZERO,Vector3(0.18,5.75,0),0.24,0.14,12)
	for y: float in [0.16,0.37,1.3,3.12,4.55]:
		j.rod(rig,"ironblue",Vector3(0.02*y,y,0),Vector3(0.02*y,y+0.13,0),0.255-y*0.012,0.255-y*0.012,12)
	j.timber(rig,"oak_red",Vector3(-0.8,4.65,-0.25),Vector3(1.7,4.52,1.35),0.19,0.2)
	for i in 7:
		var tip := Vector3(0.04,5.25,0)
		var foot := Vector3(-2.38 + i*0.12,0.55,2.49 + i*0.24)
		j.rod(rig,"cord_dark",tip+Vector3.RIGHT*i*0.03,foot,0.019)
	for anchor in [Vector3(5.6,0.85,0.05),Vector3(4.65,0.7,7.25)]:
		j.rod(rig,"cord_dark",Vector3(0.18,5.1,0),anchor,0.026)
	for x in [-0.11,0.11]:
		j.rod(rig,"cord",Vector3(1.62+x,4.54,1.30),Vector3(1.62+x,3.43,1.30),0.023)
	j.rod(rig,"brass",Vector3(1.62,3.42,1.23),Vector3(1.62,3.42,1.4),0.17,0.17,10)
	for dx: float in [-0.52,0.52]:
		j.rod(rig,"cord",Vector3(1.62,3.28,1.3), Vector3(1.62+dx,2.26,1.3),0.024)
	_bale(rig,Vector3(1.62,1.68,1.30),1.0,false)
	kit.visual(rig,BARREL,Vector3(0.15,4.0,0),Vector3(0.92,0.59,0.92)).name = "CrowsNest"


func _coil(parent: Node3D, at: Vector3, radius: float) -> void:
	var coil := _group(parent,"CoiledLine",at)
	for i in 4:
		j.ring(coil,"cord" if i % 2 else "cord_dark",Vector3.UP*0.019,(0.42+0.15*i)*radius,0.027,Vector3.RIGHT,Vector3.FORWARD,20)
	j.rod(coil,"cord",Vector3(-radius*0.75,0.018,0),Vector3(-radius*1.4,0.024,radius*0.65),0.023)


func _cargo_slate(slate: Node3D) -> void:
	for x in [-0.62,0.62]:
		j.box(slate,"frame",Vector3(x,0.83,0),Vector3(0.10,1.66,0.14))
	j.box(slate,"oak_light",Vector3(0,1.15,0),Vector3(1.64,1.36,0.15))
	j.box(slate,"soot",Vector3(0,1.15,0.08),Vector3(1.48,1.19,0.035))
	for row in 3:
		var y := 0.83 + 0.32*row
		j.box(slate,"oak_dark",Vector3(0,y-0.155,0.104),Vector3(1.38,0.016,0.015))
		_mark(slate,Vector3(-0.27,y,0.12),["diamond","crescent","triangle"][row],0.78)
		for tally in 3:
			j.timber(slate,"cord",Vector3(0.27+tally*0.09,y-0.064,0.116),Vector3(0.32+tally*0.09,y+0.064,0.116),0.019,0.014)
	for x: float in [-0.74,0.74]:
		for y: float in [0.54,1.76]:
			j.rod(slate,"brass_lit",Vector3(x,y,0.07),Vector3(x,y,0.099),0.032,0.027)


func _mark(part: Node3D, at: Vector3, kind: String, size := 1.0) -> void:
	var board := Vector3(0.80,0.34,0.024)*size
	j.box(part,"paper",at,board,Basis.IDENTITY,0.012)
	var f := at + Vector3.BACK*(board.z/2+0.003)
	for x in [-0.35,0.35]:
		j.rod(part,"brass",f+Vector3(x*size,0.10*size,0),f+Vector3(x*size,0.10*size,0.008),0.018*size,0.016*size)
	if kind == "crescent":
		var c := f + Vector3.LEFT*size*0.09
		var outer: Array[Vector3] = []
		var inner: Array[Vector3] = []
		for i in 13:
			var angle := deg_to_rad(70.0+220.0*i/12.0)
			outer.append(c + Vector3(cos(angle)*0.145,sin(angle)*0.145,0)*size)
			var inner_angle := deg_to_rad(102.0+156.0*i/12.0)
			inner.append(c + Vector3(0.077+cos(inner_angle)*0.132,sin(inner_angle)*0.14,0)*size)
		for i in 12:
			j.face(part,"ink",[outer[i],outer[i+1],inner[i+1],inner[i]],Vector3.BACK)
		for x: float in [0.095,0.205]:
			var p := f+Vector3(x,-0.062,0)*size
			j.rod(part,"ink",p,p+Vector3.BACK*0.004,0.031*size,0.031*size,10)
	elif kind == "diamond":
		j.face(part,"ironblue",[f+Vector3.UP*0.13*size,f+Vector3.RIGHT*0.13*size,f+Vector3.DOWN*0.13*size,f+Vector3.LEFT*0.13*size],Vector3.BACK)
	else:
		j.face(part,"wine",[f+Vector3.UP*0.13*size,f+Vector3(0.155,-0.10,0)*size,f+Vector3(-0.155,-0.10,0)*size],Vector3.BACK)


func _hold(hold: Node3D) -> void:
	_floor(hold,"LowerDeckPlanking",6.90,17.80,FAR,NEAR,-1.20)
	var back := _group(hold,"Spirketting")
	for k in 10:
		var y := -1.06 + k * 0.31
		j.box(back,PLANK_COLORS[(k+2)%7],Vector3(12.35,y,FAR-0.04-k*0.016),Vector3(10.94,0.293,0.19))
	j.box(back,"blue",Vector3(12.35,1.97,FAR-0.1),Vector3(10.95,0.19,0.26))
	_block(back,Vector3(12.35,0.32,FAR),Vector3(10.90,3.15,0.22))
	_rails(hold,6.90,17.80,NEAR,-1.20,false)
	for i in 6:
		var rib := _group(hold,"BentFrame%02d" % (i+1),Vector3(7.02+i*2.12,-1.2,FAR))
		var profile := [Vector3(0,0,0.30),Vector3(0,0.80,0.12),Vector3(0,2.80,0.08),Vector3(0,3.40,0.41),Vector3(0,3.78,1.05),Vector3(0,3.94,2.10)]
		for k in profile.size()-1:
			j.timber(rib,"frame" if k % 2 else "oak_dark",profile[k],profile[k+1],0.32,0.31)
		j.box(rib,"metal",Vector3(0,2.42,0.09),Vector3(0.34,0.12,0.30))
		j.timber(rib,"frame",Vector3(0,0.06,8.05),Vector3(0,0.77,8.13),0.26,0.22)
		if i in [0,5]:
			j.timber(rib,"frame",profile[-1],Vector3(0,4.01,3.84),0.25,0.28)
	j.timber(back,"tar",Vector3(6.91,2.58,-24.34),Vector3(17.79,2.58,-24.34),0.21,0.23)
	# Show the underside of the weather deck above the hull ribs. Its cut edge stays
	# behind the search aisle so the overhang frames cargo seen from the gameplay camera.
	for strake in 5:
		j.box(back, PLANK_COLORS[strake], Vector3(12.35,2.83,FAR+0.18+strake*0.38), Vector3(10.94,0.16,0.368))
	for x: float in [9.14, 13.38, 15.50]:
		j.timber(back,"frame",Vector3(x,2.66,FAR+0.32),Vector3(x,2.66,FAR+2.29),0.22,0.24)
	# Three marked consignments face the aisles. The bright labels recur in the slate.
	var sail := _crate(hold,"SailclothCrate",Vector3(8.46,-1.20,-24.52),1.65,0.93,1.17,"teal")
	_mark(sail,Vector3(0,0.54,0.625),"triangle",1.0)
	_bale(sail,Vector3(0.02,0.93,0),0.96,false)
	var silver := _crate(hold,"SilverCrate",Vector3(12.76,-1.20,-18.47),1.68,0.93,1.18,"ironblue")
	_mark(silver,Vector3(0,0.53,0.63),"diamond",1.05)
	var silver_back := _group(silver,"AisleMark",Vector3(0,0.52,-0.624))
	silver_back.rotation.y = PI
	_mark(silver_back,Vector3.ZERO,"diamond",1.05)
	_chest(hold,"MarkedCrate",Vector3(15.21,-1.20,-24.52),true)
	var bale_stand := _crate(hold,"Dunnage",Vector3(11.40,-1.20,-24.94),2.23,0.36,1.03,"oak_dark")
	_bale(bale_stand,Vector3(-0.48,0.36,0),1.12,false)
	_bale(bale_stand,Vector3(0.67,0.36,0),0.88,false)
	_bale(bale_stand,Vector3(-0.12,1.00,0),0.76,false)
	for i in 2:
		var at := Vector3(8.70 + i*0.90,-1.2,-18.48)
		kit.visual(hold,BARREL,at,Vector3(0.83,1.07,0.83)).name = "CooperedStores%d" % i
		_block(hold,at + Vector3.UP*0.49,Vector3(0.76,0.98,0.76))
	_crate(hold,"PortChest",Vector3(15.77,-1.20,-18.45),1.32,0.66,0.99,"oak_red")
	_coil(hold,Vector3(10.73,-1.17,-18.41),0.42)
	_lantern(hold, "HoldLantern", Vector3(10.67, 1.14, -25.15), Vector3(9.95, -1.2, -23.65), 3.9, 30.0)
	_lantern(hold, "ConsignmentLantern", Vector3(16.55, 1.25, -25.18), Vector3(15.55, -1.2, -23.6), 4.0, 29.0)


func _crate(parent: Node3D, title: String, at: Vector3, w: float, h: float, d: float, wood: String) -> Node3D:
	var p := _group(parent,title,at)
	j.box(p,wood,Vector3(0,h*0.49,0),Vector3(w-0.05,h-0.055,d-0.04),Basis.IDENTITY,0.055)
	for i in 5:
		var x := w*(float(i+0.5)/5-0.5)
		j.box(p,wood,Vector3(x,h-0.047,0),Vector3(w/5-0.013,0.10,d),Basis.IDENTITY,0.012)
		for z: float in [-1.0,1.0]:
			j.box(p,wood,Vector3(x,h*0.48,d*z*0.5),Vector3(w/5-0.014,h-0.14,0.026),Basis.IDENTITY,0.009)
	for z: float in [-1.0,1.0]:
		for y in [0.09,h-0.095]:
			j.box(p,"oak_dark",Vector3(0,y,z*d*0.5),Vector3(w,0.13,0.077))
	for s: float in [-1.0,1.0]:
		var x := s*w*0.34
		j.box(p,"metal",Vector3(x,h+0.007,0),Vector3(0.10,0.032,d+0.06))
		for z: float in [-1.0,1.0]:
			j.box(p,"metal",Vector3(x,h*0.5,z*(d*0.5+0.033)),Vector3(0.10,h,0.044))
			for y in [0.11,h-0.11]:
				var pin := Vector3(x,y,z*(d*0.5+0.054))
				j.rod(p,"brass",pin,pin+Vector3.BACK*z*0.012,0.025,0.020)
	_block(p,Vector3(0,h*0.5,0),Vector3(w,h,d))
	return p


func _bale(parent: Node3D, at: Vector3, s: float, solid := true) -> void:
	var bale := _group(parent,"LashedCanvas",at)
	var w := s*1.20
	var h := s*0.58
	var d := s*0.86
	j.box(bale,"canvas",Vector3(0,h/2,0),Vector3(w,h,d),Basis.IDENTITY,0.17*s)
	for x in [-w*0.28,w*0.28]:
		j.box(bale,"cord_dark",Vector3(x,h+0.008,0),Vector3(0.062,h*0.085,d*0.67))
		for side: float in [-1.0,1.0]:
			j.rod(bale,"cord",Vector3(x,h,d*0.32*side),Vector3(x,h-0.13*s,d*0.50*side),0.031*s)
			j.rod(bale,"cord_dark",Vector3(x,h-0.13*s,d*0.50*side),Vector3(x,0.11*s,d*0.50*side),0.033*s)
	for z in [-0.08*s,0.08*s]:
		j.rod(bale,"cord",Vector3(-0.42*w,h,z),Vector3(0.42*w,h,z),0.024*s)
	if solid:
		_block(bale,Vector3(0,h/2,0),Vector3(w,h,d))


func _chest(parent: Node3D, title: String, at: Vector3, transferred: bool) -> void:
	var chest := _group(parent,title,at)
	var w := 1.70 if transferred else 1.14
	var h := 0.86 if transferred else 0.74
	var d := 1.20 if transferred else 0.86
	var wood := "ironblue" if transferred else "wainscot"
	var band := "metal_lit" if transferred else "brass"
	j.box(chest,wood,Vector3(0,h*0.25,0),Vector3(w,h*0.5,d))
	for z: float in [-1.0,1.0]:
		j.box(chest,wood,Vector3(0,h*0.66,z*(d*0.5-0.05)),Vector3(w,h*0.64,0.10))
		j.box(chest,band,Vector3(0,h-0.016,z*(d*0.5-0.045)),Vector3(w,0.037,0.09))
		for s: float in [-1.0,1.0]:
			j.box(chest,band,Vector3(s*w*0.39,h*0.5,z*(d*0.50+0.012)),Vector3(0.09,h+0.022,0.038))
	for s: float in [-1.0,1.0]:
		j.box(chest,wood,Vector3(s*(w*0.5-0.05),h*0.68,0),Vector3(0.10,h*0.64,d))
		j.box(chest,band,Vector3(s*(w*0.5-0.045),h-0.014,0),Vector3(0.09,0.034,d))
	j.box(chest,"velvet",Vector3(0,h*0.50,0),Vector3(w-0.17,0.06,d-0.17))
	for s: float in [-1.0,1.0]:
		j.box(chest,"wine",Vector3(s*w*0.34,h*0.66,0),Vector3(w*0.18,h*0.29,d-0.19))
		j.box(chest,"wine",Vector3(0,h*0.66,s*d*0.335),Vector3(w*0.57,h*0.29,d*0.17))
	if transferred:
		j.box(chest,"soot",Vector3(0,h*0.54,0),Vector3(w*0.51,0.03,d*0.48))
	else:
		j.box(chest,"velvet",Vector3(0,0.52,0),Vector3(0.53,0.15,0.44),Basis(Vector3.RIGHT,0.42),0.05)
	j.box(chest,"brass",Vector3(0,0.73*h,d*0.5+0.04),Vector3(0.14,0.24,0.053))
	_mark(chest,Vector3(0,0.36*h,d*0.50+0.052),"crescent",1.10 if transferred else 0.89)
	var lid := _group(chest,"Lid",Vector3(0,h,-d*0.5))
	j.box(lid,wood,Vector3(0,0.073,d*0.5),Vector3(w+0.045,0.146,d+0.03),Basis.IDENTITY,0.040)
	for s: float in [-1.0,1.0]:
		j.box(lid,band,Vector3(s*w*0.39,0.151,d*0.50),Vector3(0.094,0.035,d+0.036))
		j.rod(lid,"brass",Vector3(s*w*0.36-0.09,0.015,0),Vector3(s*w*0.36+0.09,0.015,0),0.044)
	j.box(lid,"velvet",Vector3(0,-0.008,d*0.50),Vector3(w-0.18,0.027,d-0.16))
	if transferred:
		var slip := _group(lid,"PurserTransferSlip",Vector3(0,-0.029,d*0.66))
		# Lettering faces the inside surface and becomes upright when the lid swings open.
		slip.rotation.x = PI*0.5
		j.box(slip,"paper",Vector3.ZERO,Vector3(0.89,0.34,0.020))
		var label := Label3D.new()
		label.name = "TransferDestination"
		label.text = "PURSER"
		label.pixel_size = 0.00175
		label.font_size = 69
		label.outline_size = 0
		label.modulate = Color("412f32")
		label.position.z = 0.014
		slip.add_child(label)
		var key := _group(lid,"DispatchKey",Vector3(0,-0.054,d*0.32))
		j.ring(key,"brass_lit",Vector3(-0.17,0,0),0.087,0.020,Vector3.RIGHT,Vector3.BACK,14)
		j.box(key,"brass_lit",Vector3(0.03,0,0),Vector3(0.25,0.030,0.032))
		j.box(key,"brass_lit",Vector3(0.116,0,0.029),Vector3(0.076,0.031,0.075))
	_block(chest,Vector3(0,h/2,0),Vector3(w,h,d))


func _lantern(parent: Node3D, title: String, at: Vector3, target: Vector3, reach: float, angle: float) -> SpotLight3D:
	var lamp := _group(parent,title,at)
	# Glass, blackened roof, bail, four corner mullions and a fingertip of flame.
	j.rod(lamp,"metal",Vector3(0,-0.22,0),Vector3(0,-0.16,0),0.18,0.20,6)
	j.rod(lamp,"lamp",Vector3(0,-0.15,0),Vector3(0,0.15,0),0.14,0.155,6)
	j.rod(lamp,"brass",Vector3(0,0.14,0),Vector3(0,0.19,0),0.19,0.20,6)
	j.rod(lamp,"tar",Vector3(0,0.19,0),Vector3(0,0.31,0),0.21,0.075,6)
	for i in 6:
		var offset := Vector3(cos(i*TAU/6),0,sin(i*TAU/6))*0.15
		j.rod(lamp,"brass",offset+Vector3.DOWN*0.16,offset+Vector3.UP*0.16,0.013,0.014,5)
	j.ring(lamp,"metal",Vector3(0,0.37,0),0.069,0.011,Vector3.RIGHT,Vector3.UP,12)
	j.timber(lamp,"metal",Vector3(0,0.45,-0.39),Vector3(0,0.45,0),0.046,0.046)
	return LIGHTS.add_spot(lamp, "Light", Vector3(0, -0.20, 0.13), target - at,
		Color("ffbb77"), 3.5, reach, angle)


func _passages(root: Node3D) -> void:
	var rows := [[-24.35,2.54,"StarboardCompanionway"],[-21.65,2.51,"MainCompanionway"],[-18.85,2.55,"PortCompanionway"]]
	for row in rows:
		_stair(root,row[2],17.80,21.80,row[0],-1.20,0.65,row[1])
	for z: float in [FAR,-23.0,-20.28,NEAR]:
		var side := _group(root,"CompanionRail")
		var h := 0.76 if z < NEAR else 0.40
		for i in 4:
			var t := float(i)/3
			var foot := Vector3(lerpf(17.8,21.8,t),lerpf(-1.20,0.65,t),z)
			j.box(side,"frame",foot + Vector3.UP*h/2,Vector3(0.15,h,0.15))
			j.box(side,"brass",foot + Vector3.UP*(h-0.075),Vector3(0.16,0.04,0.16))
		j.timber(side,"oak_light",Vector3(17.8,-1.20+h,z),Vector3(21.8,0.65+h,z),0.1,0.13)
		j.timber(side,"teal",Vector3(17.8,-1.03,z),Vector3(21.8,0.82,z),0.36,0.16)
		_block(side,Vector3(19.8,-0.275+h/2,z),Vector3(4.45,h,0.19),atan2(1.85,4.0))
	var wall := _group(root,"StarboardPortholes")
	for k in 11:
		j.timber(wall,"wainscot" if k % 3 else "oak_dark",Vector3(17.78,-1.13+k*0.275,FAR-0.12),Vector3(21.85,0.72+k*0.275,FAR-0.12),0.26,0.17)
	for i in 3:
		var x := 18.43+i*1.35
		var y := -1.20+(x-17.80)*1.85/4+1.44
		var at := Vector3(x,y,FAR-0.004)
		j.rod(wall,"glass",at,at+Vector3.BACK*0.05,0.34,0.34,20)
		j.ring(wall,"brass",at+Vector3.BACK*0.10,0.36,0.052,Vector3.RIGHT,Vector3.UP,24)
		j.ring(wall,"brass_lit",at+Vector3.BACK*0.113,0.31,0.009,Vector3.RIGHT,Vector3.UP,24)
		for k in 6:
			var ang := k*TAU/6
			var dot_at := at + Vector3(cos(ang)*0.36,sin(ang)*0.36,0.115)
			j.rod(wall,"metal",dot_at,dot_at+Vector3.BACK*0.01,0.022,0.020)
	_block(wall,Vector3(19.80,1.25,FAR),Vector3(4.08,4.5,0.20))
	# Companionway head is open, with a fixed-back night door against the inner partition.
	var entry := _group(root,"PurserDoorFrame",Vector3(21.77,0.65,-24.34))
	for s: float in [-1.0,1.0]:
		j.box(entry,"oak_dark",Vector3(0,1.24,s*1.18),Vector3(0.22,2.48,0.22))
		j.timber(entry,"oak",Vector3(0,2.02,s*1.16),Vector3(0,2.47,s*0.76),0.16,0.19)
	j.timber(entry,"oak_dark",Vector3(0,2.49,-1.30),Vector3(0,2.49,1.30),0.22,0.25)
	_lantern(root, "CabinDoorLamp", Vector3(21.35, 2.35, -25.39), Vector3(21.7, 0.45, -24.35), 3.5, 32.0)


func _cabin(cabin: Node3D) -> void:
	_floor(cabin,"CabinSole",21.80,28.12,FAR,NEAR,0.65)
	_rails(cabin,21.8,28.1,NEAR,0.65,false)
	var back := _group(cabin,"SternGallery")
	for k in 13:
		j.box(back,["wainscot","oak_dark","oak_red"][k%3],Vector3(24.96,0.78+k*0.26,FAR-0.10),Vector3(6.39,0.249,0.20))
	j.box(back,"oak_light",Vector3(25.0,1.84,FAR+0.034),Vector3(6.45,0.14,0.19))
	j.box(back,"brass",Vector3(25.0,1.86,FAR+0.145),Vector3(6.40,0.027,0.028))
	j.box(back,"frame",Vector3(25.0,3.97,FAR),Vector3(6.46,0.20,0.33))
	for i in 6:
		var x := 22.26+i*1.06
		j.box(back,"frame",Vector3(x,1.30,FAR+0.015),Vector3(0.075,1.23,0.14))
	for i in 3:
		_gallery_window(back,Vector3(23.94 + i*1.12,1.90,FAR+0.044),i)
	for x: float in [21.97,27.80]:
		j.timber(back,"frame",Vector3(x,0.68,FAR+0.09),Vector3(x,3.2,FAR+0.12),0.28,0.28)
		j.timber(back,"oak_dark",Vector3(x,2.87,FAR+0.13),Vector3(x,3.85,FAR+0.73),0.25,0.26)
		j.timber(back,"frame",Vector3(x,3.84,FAR+0.73),Vector3(x,4.17,FAR+1.58),0.26,0.28)
	_block(back,Vector3(24.98,2.19,FAR),Vector3(6.36,3.12,0.20))
	_chest(cabin,"Strongbox",Vector3(25.05,0.65,-24.46),false)
	_lantern(cabin, "PurserLantern", Vector3(23.17, 2.52, -25.33), Vector3(24.75, 0.7, -24.15), 4.0, 33.0)
	_pigeonholes(cabin, Vector3(27.03,0.65,-25.00))
	_chart_table(cabin)
	var rug := _group(cabin,"WoolRunner",Vector3(25.03,0.665,-21.7))
	j.box(rug,"wine",Vector3.ZERO,Vector3(1.79,0.019,3.03),Basis.IDENTITY,0.001)
	for s: float in [-1.0,1.0]:
		j.box(rug,"cord",Vector3(s*0.81,0.011,0),Vector3(0.027,0.005,2.94),Basis.IDENTITY,0)
		for off in [1.28,1.34]:
			j.box(rug,"cord_dark",Vector3(0,0.012,s*off),Vector3(1.76,0.006,0.029),Basis.IDENTITY,0)
	for i in 16:
		for s: float in [-1.0,1.0]:
			j.box(rug,"cord",Vector3((i-7.5)*0.101,0.002,s*1.535),Vector3(0.031,0.013,0.092),Basis.IDENTITY,0)
	var transom := _group(cabin,"Transom")
	j.box(transom,"teal",Vector3(28.13,0.90,-21.65),Vector3(0.22,0.5,8.23))
	j.box(transom,"oak_light",Vector3(28.13,1.18,-21.65),Vector3(0.28,0.13,8.3))
	for i in 6:
		j.box(transom,"frame",Vector3(28.12,1.12,-25.45+i*1.48),Vector3(0.22,0.93,0.19))


func _gallery_window(parent: Node3D, at: Vector3, index: int) -> void:
	var window := _group(parent,"ArchedSternLight%d" % (index+1),at)
	var radius := 0.455
	var y_arch := 1.01
	for side: float in [-1.0,1.0]:
		j.box(window,"frame",Vector3(side*(radius+0.046),0.50,0.068),Vector3(0.084,1.11,0.14))
	j.box(window,"glass",Vector3(0,0.52,0.055),Vector3(radius*2,1.03,0.027))
	# A low shore and its lights sit behind all three panes of the gallery.
	for column in 7:
		var left := -0.451 + column*0.129
		var station := index*7 + column
		var h0 := 0.49 + 0.065*sin(station*1.52) + 0.07*cos(station*0.64)
		var h1 := 0.49 + 0.065*sin((station+1)*1.52) + 0.07*cos((station+1)*0.64)
		j.face(window,"harbor",[Vector3(left,0.35,0.074),Vector3(left+0.129,0.35,0.074),
			Vector3(left+0.129,h1,0.074),Vector3(left,h0,0.074)],Vector3.BACK)
		if station % 4 == 0:
			j.box(window,"ember",Vector3(left+0.06,0.37,0.08),Vector3(0.029,0.014,0.003),Basis.IDENTITY,0)
	if index == 1:
		j.rod(window,"moon",Vector3(0.18,1.035,0.079),Vector3(0.18,1.035,0.082),0.093,0.093,20)
	for i in 12:
		var a := PI*i/12
		var b := PI*(i+1)/12
		var m := Vector3(0,y_arch,0.065)
		var start := m + Vector3(cos(a),sin(a),0)*radius
		var end := m + Vector3(cos(b),sin(b),0)*radius
		j.face(window,"glass",[m,start,end],Vector3.BACK)
		j.timber(window,"oak_light",start+Vector3.BACK*0.03,end+Vector3.BACK*0.03,0.085,0.12)
	for h: float in [0.39,0.81]:
		j.box(window,"frame",Vector3(0,h,0.099),Vector3(0.90,0.045,0.043))
	j.box(window,"frame",Vector3(0,0.73,0.104),Vector3(0.049,1.46,0.048))
	j.box(window,"oak_light",Vector3(0,-0.01,0.11),Vector3(1.10,0.12,0.24))
	for i in 3:
		var reflection := Vector3(0.18-i*0.08,0.18+0.21*i,0.085)
		j.timber(window,"glass_light",reflection,reflection+Vector3(0.17,0.035,0),0.018,0.007)


func _pigeonholes(parent: Node3D, at: Vector3) -> void:
	var rack := _group(parent,"DispatchPigeonholes",at)
	j.box(rack,"oak_dark",Vector3(0,0.47,0),Vector3(1.27,0.93,0.50))
	j.box(rack,"tar",Vector3(0,1.48,-0.16),Vector3(1.22,1.10,0.10))
	for i in 4:
		j.box(rack,"oak",Vector3((i-1.5)*0.40,1.49,0.023),Vector3(0.051,1.14,0.45))
	for i in 3:
		j.box(rack,"oak_light",Vector3(0,0.94+i*0.55,0.023),Vector3(1.32,0.060,0.49))
	for i in 5:
		var x := (i%3-1)*0.40
		var y := 1.09+(i/3)*0.55
		j.rod(rack,"paper",Vector3(x-0.06,y,-0.13),Vector3(x+0.04,y+0.024,0.22),0.071,0.074)
		j.rod(rack,"cord_dark",Vector3(x+0.035,y+0.024,0.222),Vector3(x+0.038,y+0.025,0.224),0.035,0.030)
	for s: float in [-1.0,1.0]:
		j.box(rack,"frame",Vector3(s*0.31,0.47,0.255),Vector3(0.53,0.68,0.035))
		j.box(rack,"brass",Vector3(s*0.17,0.49,0.284),Vector3(0.08,0.04,0.03))
	_block(rack,Vector3(0,0.99,0),Vector3(1.27,1.98,0.51))


func _chart_table(parent: Node3D) -> void:
	var desk := _group(parent,"ChartTable",Vector3(26.91,0.65,-22.18))
	for x: float in [-1.0,1.0]:
		for z: float in [-0.46,0.46]:
			j.box(desk,"frame",Vector3(x,0.43,z),Vector3(0.155,0.86,0.155))
	j.box(desk,"oak_red",Vector3(0,0.83,0),Vector3(2.38,0.155,1.15))
	j.box(desk,"oak_dark",Vector3(0,0.65,0),Vector3(2.17,0.23,1.02))
	var chart := MeshInstance3D.new()
	chart.name = "PurserChart"
	var page := PlaneMesh.new()
	page.size = Vector2(1.19,0.75)
	page.material = load("res://Materials/TheLastBarrel/pursers_chart.tres")
	chart.mesh = page
	chart.position = Vector3(-0.17,0.911,0.045)
	chart.rotation.y = 0.13
	desk.add_child(chart)
	for z in [-0.34,0.29]:
		j.rod(desk,"paper",Vector3(-1.03,0.974,z),Vector3(-0.67,0.974,z-0.08),0.066)
	var center := Vector3(0.77,1.22,-0.12)
	j.rod(desk,"brass",center+Vector3.DOWN*0.31,center+Vector3.DOWN*0.27,0.157,0.13,12)
	j.rod(desk,"brass_lit",center+Vector3.DOWN*0.27,center+Vector3.DOWN*0.09,0.055,0.032)
	j.ring(desk,"brass",center,0.197,0.022,Vector3.RIGHT,Vector3.UP,24)
	j.ring(desk,"brass_lit",center,0.165,0.015,Vector3(0.74,0,0.67).normalized(),Vector3.UP,20)
	j.ring(desk,"brass_lit",center,0.172,0.013,Vector3.RIGHT,Vector3(0,0.40,-0.92).normalized(),20)
	j.rod(desk,"teal",center-Vector3.UP*0.055,center+Vector3.UP*0.055,0.066)
	_block(desk,Vector3(0,0.44,0),Vector3(2.30,0.89,1.10))
