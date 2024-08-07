// Copyright 2024 peter-jerry-ye
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Represent memory 内存
pub(readonly) struct Memory {
  offset : Int
  length : Int
  priv bytes : Bytes
} derive(Debug)

/// Load Byte 读取字节
pub fn load8(self : Memory, offset : Int) -> Int? {
  if offset < 0 || offset + 1 > self.length {
    None
  } else {
    Some(self.bytes[offset].to_int())
  }
}

/// Load Int32 读取32位整数
pub fn load32(self : Memory, offset : Int) -> Int? {
  if offset < 0 || offset + 4 > self.length {
    None
  } else {
    let b1 = self.bytes[offset].to_int()
    let b2 = self.bytes[offset + 1].to_int()
    let b3 = self.bytes[offset + 2].to_int()
    let b4 = self.bytes[offset + 3].to_int()
    Some((b4 << 24) | (b3 << 16) | (b2 << 8) | b1)
  }
}

/// Load Int64 读取64位整数
pub fn load64(self : Memory, offset : Int) -> Int64? {
  if offset < 0 || offset + 8 > self.length {
    None
  } else {
    let b1 = self.bytes[offset].to_int64()
    let b2 = self.bytes[offset + 1].to_int64()
    let b3 = self.bytes[offset + 2].to_int64()
    let b4 = self.bytes[offset + 3].to_int64()
    let b5 = self.bytes[offset + 4].to_int64()
    let b6 = self.bytes[offset + 5].to_int64()
    let b7 = self.bytes[offset + 6].to_int64()
    let b8 = self.bytes[offset + 7].to_int64()
    Some(
      (b8 << 56) | (b7 << 48) | (b6 << 40) | (b5 << 32) | (b4 << 24) | (b3 << 16) |
      (b2 << 8) | b1,
    )
  }
}

/// Load Float64 读取64位浮点数
pub fn loadf64(self : Memory, offset : Int) -> Double? {
  self.load64(offset).map(reinterpret_as_double)
}

/// Store Byte 存储字节
pub fn store8(self : Memory, offset : Int, value : Int) -> Unit? {
  if offset < 0 || offset + 1 > self.length {
    None
  } else {
    self.bytes[offset] = value.to_byte()
    Some(())
  }
}

/// Store Int32 存储32位整数
pub fn store32(self : Memory, offset : Int, value : Int) -> Unit? {
  if offset < 0 || offset + 4 > self.length {
    None
  } else {
    self.bytes[offset] = (value & 0xFF).to_byte()
    self.bytes[offset + 1] = ((value >> 8) & 0xFF).to_byte()
    self.bytes[offset + 2] = ((value >> 16) & 0xFF).to_byte()
    self.bytes[offset + 3] = ((value >> 24) & 0xFF).to_byte()
    Some(())
  }
}

/// Store Int64 存储64位整数
pub fn store64(self : Memory, offset : Int, value : Int64) -> Unit? {
  if offset < 0 || offset + 8 > self.length {
    None
  } else {
    self.bytes[offset] = (value & 0xF).to_byte()
    self.bytes[offset + 1] = ((value >> 8) & 0xFF).to_byte()
    self.bytes[offset + 2] = ((value >> 16) & 0xFF).to_byte()
    self.bytes[offset + 3] = ((value >> 24) & 0xFF).to_byte()
    self.bytes[offset + 4] = ((value >> 32) & 0xFF).to_byte()
    self.bytes[offset + 5] = ((value >> 40) & 0xFF).to_byte()
    self.bytes[offset + 6] = ((value >> 48) & 0xFF).to_byte()
    self.bytes[offset + 7] = ((value >> 56) & 0xFF).to_byte()
    Some(())
  }
}

/// Store Float64 存储64位浮点数
pub fn storef64(self : Memory, offset : Int, value : Double) -> Unit? {
  if offset < 0 || offset + 8 > self.length {
    None
  } else {
    self.store64(offset, value.reinterpret_as_i64())
  }
}

/// Load Bytes 读取数据块
pub fn load_bytes(self : Memory) -> Bytes {
  let bytes = Bytes::new(self.length)
  bytes.blit(0, self.bytes, 0, self.length)
  bytes
}

/// Store Bytes 存储数据块
pub fn store_bytes(self : Memory, bytes : Bytes) -> Unit {
  let len = if self.length < bytes.length() {
    self.length
  } else {
    bytes.length()
  }
  self.bytes.blit(0, bytes, 0, len)
}

extern "wasm" fn get_bytes(offset : Int) -> Bytes =
  #|(func (param i32) (result i32) local.get 0 i32.const 8 i32.sub call $rael.incref local.get 0 i32.const 8 i32.sub)

extern "wasm" fn get_offset(bytes : Bytes) -> Int =
  #|(func (param i32) (result i32) local.get 0 call $rael.decref local.get 0 i32.const 8 i32.add)

extern "wasm" fn alloc(bytes : Bytes) =
  #|(func (param i32))

extern "wasm" fn release(bytes : Bytes) =
  #|(func (param i32) local.get 0 call $rael.decref local.get 0 call $rael.decref)

extern "wasm" fn is_bytes(offset : Int) -> Bool =
  #|(func (param i32) (result i32) local.get 0 i32.const 4 i32.sub i32.load8_u i32.const 246 i32.eq)

fn verify(offset : Int, length : Int) -> Bool {
  is_bytes(offset) && get_bytes(offset).length() == length
}

/// Create memory 创建内存
/// Only valid if it is actually an allocated memory that is in use
/// 当该内存确实为被分配的内存时输入合法
pub fn Memory::make(offset : Int, length : Int) -> Memory? {
  @option.when(
    verify(offset, length),
    fn() { Memory::{ offset, length, bytes: get_bytes(offset) } },
  )
}

/// Allocate memory 分配内存
pub fn allocate(size : Int) -> Memory? {
  if size <= 0 {
    return None
  }
  let bytes = Bytes::new(size)
  alloc(bytes)
  Some({ offset: get_offset(bytes), length: size, bytes })
}

/// Free Memory 释放内存
pub fn free(self : Memory) -> Unit? {
  Some(release(self.bytes))
}

/// Reallocate Memory 重新分配内存
pub fn reallocate(self : Memory, _alignment : Int, new_length : Int) -> Memory? {
  if self.length <= 0 {
    allocate(new_length)
  } else if new_length <= 0 {
    self.free() |> ignore
    None
  } else {
    let new = allocate(new_length)?
    new.bytes.blit(0, self.bytes, 0, new_length)
    self.free() |> ignore
    Some(new)
  }
}
