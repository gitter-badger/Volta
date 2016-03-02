// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.gtors;


extern(C) void vrt_run_global_ctors()
{
	auto mod = object.moduleInfoRoot;
	while (mod !is null) {
		foreach (fn; mod.ctors) {
			fn();
		}
		mod = mod.next;
	}
}

extern(C) void vrt_run_global_dtors()
{
	auto mod = object.moduleInfoRoot;
	while (mod !is null) {
		foreach (fn; mod.dtors) {
			fn();
		}
		mod = mod.next;
	}
}
