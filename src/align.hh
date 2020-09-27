#pragma once

#include "common.hh"

template<typename T>
T align_up(T val, T mod) {
  if(val & (mod - 1)) {
    val &= ~(mod - 1);
    val += mod;
  }
  return val;
}

template<typename T>
bool is_aligned(T val, T mod) {
  if(val & (mod - 1)) {
    return false;
  }
  return true;
}

inline u64 align_page_size_up(u64 val) {
  return align_up<u64>(val, page_size);
}
