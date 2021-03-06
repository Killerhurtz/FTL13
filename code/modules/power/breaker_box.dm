// Updated version of old powerswitch by Atlantis from /tg/
// Has better texture, and is now considered electronic device
// AI has ability to toggle it in 5 seconds
// Humans need 30 seconds (AI is faster when it comes to complex electronics)
// Used for advanced grid control (read: Substations)

/obj/machinery/power/breakerbox
  name = "Breaker Box"
  icon = 'icons/obj/power.dmi'
  icon_state = "bbox_off"
  //directwired = 0
  var/icon_state_on = "bbox_on"
  var/icon_state_off = "bbox_off"
  density = 1
  anchored = 1
  var/on = 0
  var/busy = 0
  var/directions = list(1,2,4,8,5,6,9,10)
  var/update_locked = 0
  var/department = "Generic" //soft tabs? AAAAAAAA
  var/status = "offline.<br>"
  var/id = ""

/obj/machinery/power/breakerbox/proc/id_gen()
  var/list/abc = list("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z")
  var/list/num = list(0, 1, 2, 3, 4, 5, 6, 7, 8, 9)

  //one letter, two numbers
  var/one = "[pick(abc)]"
  var/two = "[pick(num)]"
  var/three = "[pick(num)]"

  id += one
  id += two
  id += three

/obj/machinery/power/breakerbox/Destroy()
	..()
  /*
	for(var/datum/nano_module/rcon/R in world)
		R.FindDevices()
  */

/obj/machinery/power/breakerbox/New()
  id_gen()
  ..()

/obj/machinery/power/breakerbox/activated
  icon_state = "bbox_on"
  status = "online.<br>"

	// Enabled on server startup. Used in substations to keep them in bypass mode.
/obj/machinery/power/breakerbox/activated/initialize()
  set_state(1)

/obj/machinery/power/breakerbox/examine(mob/user)
	user << "Large machine with heavy duty switching circuits used for advanced grid control"
	if(on)
		user << "<span class='info'>It seems to be online.</span>"
	else
		user << "<span class='warning'>It seems to be offline.</span>"

/obj/machinery/power/breakerbox/attack_ai(mob/user)
  if(update_locked)
    user << "<span class='warning'>System locked. Please try again later.</span>"
    if(on)
      status = "online and locked.<br>"
    else
      status = "offline and locked.<br>"
    return

  if(busy)
    user << "<span class='warning'>System is busy. Please wait until current operation is finished before changing power settings.</span>"
    status = "in the process of reprogramming.<br>"
    return

  busy = 1
  user << "<span class='info'>Updating power settings...</span>"
  if(do_after(user, 50, src))
    set_state(!on)
    user << "<span class='info'>Update Completed. New setting:[on ? "on": "off"]</span>"
    status = "[on ? "on": "off"].<br>"
    update_locked = 1
    spawn(600)
      update_locked = 0
  busy = 0


/obj/machinery/power/breakerbox/attack_hand(mob/user)
  if(update_locked)
    user << "<span class='warning'>System locked. Please try again later.</span>"
    if(on)
      status = "online and locked.<br>"
    else
      status = "offline and locked.<br>"
    return

  if(busy)
    user << "<span class='warning'>System is busy. Please wait until current operation is finished before changing power settings.</span>"
    status = "in the process of reprogramming.<br>"
    return

  busy = 1
  user.visible_message("[user] started reprogramming [src]!", "<span class='notice'>You start reprogramming [src].</span>")

  if(do_after(user, 50,src))
    set_state(!on)
    user.visible_message(\
    "<span class='notice'>[user.name] [on ? "enabled" : "disabled"] the breaker box!</span>",\
    "<span class='notice'>You [on ? "enabled" : "disabled"] the breaker box!</span>")
    status = "[on ? "on": "off"].<br>"
    update_locked = 1
    spawn(600)
      update_locked = 0
  busy = 0


/obj/machinery/power/breakerbox/attackby(var/obj/item/weapon/W as obj, var/mob/user as mob)
  if(istype(W, /obj/item/device/multitool))
    if(on)
      var/list/departments = list("Engineering", "Medical", "Command", "Security", "Research", "Supply and Munitions", "Civilian", "Custom...")
      var/dep = input(user, "Set the department this breaker box is bound to. Used for identification only.", "Set department") as null|anything in departments
      if(dep)
        if(dep == "Custom...")
          var/depc = input(user, "Enter the custom department designation for the breaker box:", "Custom designation") as text
          if(depc)
            department = depc
        else
          department = dep
    else
      user << "<span class='warning'>You cannot access a breaker box which is offline!</span>"

/obj/machinery/power/breakerbox/proc/remote_toggle()
  if(update_locked)
    if(on)
      status = "online and locked.<br>"
    else
      status = "offline and locked.<br>"
    return

  if(busy)
    status = "in the process of reprogramming.<br>"
    return

  busy = 1
  src.visible_message("The breaker box seems to be [on ? "shutting itself down" : "booting itself up"].")

  spawn(50)
    set_state(!on)
    status = "[on ? "on": "off"].<br>"
    update_locked = 1
    spawn(600)
      update_locked = 0
  busy = 0

/obj/machinery/power/breakerbox/proc/set_state(var/state)
	on = state
	if(on)
		icon_state = icon_state_on
		var/list/connection_dirs = list()
		for(var/direction in directions)
			for(var/obj/structure/cable/C in get_step(src,direction))
				if(C.d1 == turn(direction, 180) || C.d2 == turn(direction, 180))
					connection_dirs += direction
					break

		for(var/direction in connection_dirs)
			var/obj/structure/cable/C = new/obj/structure/cable(src.loc)
			C.d1 = 0
			C.d2 = direction
			C.icon_state = "[C.d1]-[C.d2]"
			C.breaker_box = src

			var/datum/powernet/PN = new()
			PN.add_cable(C)

			C.mergeConnectedNetworks(C.d2)
			C.mergeConnectedNetworksOnTurf()

			if(C.d2 & (C.d2 - 1))// if the cable is layed diagonally, check the others 2 possible directions
				C.mergeDiagonalsNetworks(C.d2)

	else
		icon_state = icon_state_off
		for(var/obj/structure/cable/C in src.loc)
			qdel(C)

// Used by RCON to toggle the breaker box.
/*
/obj/machinery/power/breakerbox/proc/auto_toggle()
	if(!update_locked)
		set_state(!on)
		update_locked = 1
		spawn(600)
			update_locked = 0
*/
/obj/machinery/power/breakerbox/proc/updatestatus()
  if(on)
    status = "online.<br>"
  if(!on)
    status = "offline.<br>"
  if(busy)
    status = "in the process of reprogramming.<br>"
  if(on && update_locked)
    status = "online and locked.<br>"
  if(!on && update_locked)
    status = "offline and locked.<br>"

/obj/machinery/power/breakerbox/process()
  updatestatus()
  return 1
