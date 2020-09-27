#pragma once

#include "common.hh"

u64 devicetree_get_phys_high();
void devicetree_parse(bool init_fb, bool boot_aps);
