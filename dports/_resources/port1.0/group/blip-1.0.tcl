proc blip.revision {r} {
    global revision blip_revision
    set blip_revision ${r}
    if {[variant_isset blip]} {
	revision ${revision}.${r}
    }
}
