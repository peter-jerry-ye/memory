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
} derive(Show)

/// Load Byte 读取字节
pub fn load8(self : Memory, offset : Int) -> Int? {
  if offset < 0 || offset + 1 > self.length {
    None
  } else {
    Some(load8_ffi(self.offset + offset))
  }
}

/// Load Int32 读取32位整数
pub fn load32(self : Memory, offset : Int) -> Int? {
  if offset < 0 || offset + 4 > self.length {
    None
  } else {
    Some(load32_ffi(self.offset + offset))
  }
}

/// Load Int64 读取64位整数
pub fn load64(self : Memory, offset : Int) -> Int64? {
  if offset < 0 || offset + 8 > self.length {
    None
  } else {
    Some(load64_ffi(self.offset + offset))
  }
}

/// Load Float64 读取64位浮点数
pub fn loadf64(self : Memory, offset : Int) -> Double? {
  if offset < 0 || offset + 8 > self.length {
    None
  } else {
    Some(loadf64_ffi(self.offset + offset))
  }
}

/// Store Byte 存储字节
pub fn store8(self : Memory, offset : Int, value : Int) -> Unit? {
  if offset < 0 || offset + 1 > self.length {
    None
  } else {
    Some(store8_ffi(self.offset + offset, value))
  }
}

/// Store Int32 存储32位整数
pub fn store32(self : Memory, offset : Int, value : Int) -> Unit? {
  if offset < 0 || offset + 4 > self.length {
    None
  } else {
    Some(store32_ffi(self.offset + offset, value))
  }
}

/// Store Int64 存储64位整数
pub fn store64(self : Memory, offset : Int, value : Int64) -> Unit? {
  if offset < 0 || offset + 8 > self.length {
    None
  } else {
    Some(store64_ffi(self.offset + offset, value))
  }
}

/// Store Float64 存储64位浮点数
pub fn storef64(self : Memory, offset : Int, value : Double) -> Unit? {
  if offset < 0 || offset + 8 > self.length {
    None
  } else {
    Some(storef64_ffi(self.offset + offset, value))
  }
}

/// Load Bytes 读取数据块
pub fn load_bytes(self : Memory) -> Bytes {
  let bytes = Bytes::new(self.length)
  for i = 0; i < self.length; i = i + 1 {
    bytes[i] = load8_ffi(self.offset + i).to_byte()
  }
  bytes
}

/// Store Bytes 存储数据块
pub fn store_bytes(self : Memory, bytes : Bytes) -> Unit {
  let len = if self.length < bytes.length() {
    self.length
  } else {
    bytes.length()
  }
  for i = 0; i < len; i = i + 1 {
    store8_ffi(self.offset + i, bytes[i].to_int())
  }
}

extern "wasm" fn load8_ffi(pos : Int) -> Int =
  #|(func (param $pos i32) (result i32) (i32.load8_u (local.get $pos)))

extern "wasm" fn load32_ffi(pos : Int) -> Int =
  #|(func (param $pos i32) (result i32) (i32.load (local.get $pos)))

extern "wasm" fn load64_ffi(pos : Int) -> Int64 =
  #|(func (param $pos i32) (result i64) (i64.load (local.get $pos)))

extern "wasm" fn loadf64_ffi(pos : Int) -> Double =
  #|(func (param $pos i32) (result f64) (f64.load (local.get $pos)))

extern "wasm" fn store8_ffi(pos : Int, value : Int) =
  #|(func (param $pos i32) (param $value i32) (i32.store8 (local.get $pos) (local.get $value)))

extern "wasm" fn store32_ffi(pos : Int, value : Int) =
  #|(func (param $pos i32) (param $value i32) (i32.store (local.get $pos) (local.get $value)))

extern "wasm" fn store64_ffi(pos : Int, value : Int64) =
  #|(func (param $pos i32) (param $value i64) (i64.store (local.get $pos) (local.get $value)))

extern "wasm" fn storef64_ffi(pos : Int, value : Double) =
  #|(func (param $pos i32) (param $value f64) (f64.store (local.get $pos) (local.get $value)))

extern "wasm" fn memory_size_ffi() -> Int =
  #|(func (result i32) (memory.size))

extern "wasm" fn memory_grow_ffi(delta : Int) -> Int =
  #|(func (param $size i32) (result i32) (memory.grow (local.get $size)))

extern "wasm" fn memory_copy_ffi(origin : Int, target : Int, len : Int) =
  #|(func (param $origin i32) (param $target i32) (param $len i32) (memory.copy (local.get $origin) (local.get $target) (local.get $len)))

priv struct Chunk {
  mut memory : Memory
  mut occupied : Bool
  mut prev : Chunk?
  mut next : Chunk?
} derive(Show)

priv struct LinearMemory {
  mut start : Chunk
  mut end : Chunk
}

impl Show for LinearMemory with output(self : LinearMemory, logger : Logger) -> Unit {
  (self.to_array() as Show).output(logger)
}

fn to_array(self : LinearMemory) -> Array[(Memory, Bool)] {
  let length = loop Option::Some(self.start), 0 {
    None, cumul => cumul
    Some(chunk), cumul => continue chunk.next, cumul + 1
  }
  let array = Array::make(length, ({ offset: 0, length: 0 }, true))
  loop Option::Some(self.start), 0 {
    None, _ => ()
    Some(chunk), index => {
      array[index] = (chunk.memory, chunk.occupied)
      continue chunk.next, index + 1
    }
  }
  array
}

let memory : LinearMemory = {
  let length = memory_size_ffi().lsl(16)
  let chunk = {
    memory: { offset: 0, length },
    occupied: false,
    prev: None,
    next: None,
  }
  { start: chunk, end: chunk }
}

/// Create memory 创建内存
/// Only valid if it is actually an allocated memory that is in use
/// 当该内存确实为被分配的内存时输入合法
pub fn Memory::make(offset : Int, length : Int) -> Memory? {
  { offset, length }.locate_chunk().map(fn { chunk => chunk.memory })
}

fn Memory::locate_chunk(m : Memory) -> Chunk? {
  loop Option::Some(memory.start) {
    None => None
    Some(chunk) =>
      if chunk.memory.length == m.length && chunk.memory.offset == m.offset {
        Some(chunk)
      } else if chunk.memory.offset < m.offset {
        continue chunk.next
      } else {
        None
      }
  }
}

fn grow(self : LinearMemory, size : Int) -> Bool {
  let delta = size.lsr(16) + 1
  let old_size = memory_size_ffi()
  let errno = memory_grow_ffi(delta)
  if errno != -1 {
    if self.end.occupied {
      let chunk : Chunk = {
        memory: { offset: old_size.lsl(16), length: delta.lsl(16) },
        occupied: false,
        prev: Some(self.end),
        next: None,
      }
      self.end.next = Some(chunk)
      self.end = chunk
    } else {
      self.end.memory = {
        ..self.end.memory,
        length: self.end.memory.length + delta.lsl(16),
      }
    }
    true
  } else {
    false
  }
}

/// Allocate memory 分配内存
pub fn allocate(size : Int) -> Memory? {
  if size <= 0 {
    return None
  }
  loop Option::Some(memory.start) {
    Some({ occupied: false, .. } as chunk) =>
      if chunk.memory.length < size {
        continue chunk.next
      } else {
        if chunk.memory.length > size {
          match chunk.split(size) {
            None => return None
            _ => ()
          }
        }
        chunk.occupied = true
        Some(chunk.memory)
      }
    Some(chunk) => continue chunk.next
    None => if memory.grow(size) { allocate(size) } else { None }
  }
}

/// return merged or self
fn Chunk::merge_next(chunk : Chunk, next : Chunk) -> Chunk {
  chunk.memory = {
    ..chunk.memory,
    length: chunk.memory.length + next.memory.length,
  }
  match next.next {
    Some(next_next) => {
      chunk.next = Some(next_next)
      next_next.prev = Some(chunk)
    }
    None => {
      chunk.next = None
      memory.end = chunk
    }
  }
  chunk
}

/// return next
fn Chunk::split(chunk : Chunk, length : Int) -> Chunk? {
  if length < chunk.memory.length {
    let new_chunk : Chunk = {
      memory: {
        offset: chunk.memory.offset + length,
        length: chunk.memory.length - length,
      },
      occupied: false,
      prev: Some(chunk),
      next: chunk.next,
    }
    chunk.memory = { ..chunk.memory, length, }
    chunk.next = Some(new_chunk)
    match new_chunk.next {
      None => memory.end = new_chunk
      Some(next_next) => next_next.prev = Some(new_chunk)
    }
    Some(new_chunk)
  } else {
    None
  }
}

fn Chunk::free(chunk : Chunk) -> Unit {
  chunk.occupied = false
  let chunk = match chunk.prev {
    Some({ occupied: false, .. } as prev) => prev.merge_next(chunk)
    _ => chunk
  }
  match chunk.next {
    Some({ occupied: false, .. } as next) => chunk.merge_next(next) |> ignore
    _ => ()
  }
}

/// Free Memory 释放内存
pub fn free(self : Memory) -> Unit? {
  let chunk = match self.locate_chunk() {
    Some(chunk) => chunk
    None => return None
  }
  if chunk.occupied {
    Some(chunk.free())
  } else {
    None
  }
}

/// Reallocate Memory 重新分配内存
pub fn reallocate(self : Memory, _alignment : Int, new_length : Int) -> Memory? {
  if self.length <= 0 {
    allocate(new_length)
  } else if new_length <= 0 {
    self.free() |> ignore
    None
  } else if new_length < self.length {
    let chunk = match self.locate_chunk() {
      None => return None
      Some(chunk) => chunk
    }
    if chunk.occupied {
      match chunk.next {
        Some({ occupied: false, .. } as next) => {
          chunk.merge_next(next) |> ignore
          chunk.split(new_length) |> ignore
          Some(chunk.memory)
        }
        _ => {
          chunk.split(new_length) |> ignore
          Some(chunk.memory)
        }
      }
    } else {
      None
    }
  } else {
    let chunk = match self.locate_chunk() {
      None => return None
      Some(chunk) => chunk
    }
    if chunk.occupied {
      chunk.occupied = false
      let chunk = match chunk.prev {
        Some({ occupied: false, .. } as prev) => prev.merge_next(chunk)
        _ => chunk
      }
      match chunk.next {
        Some({ occupied: false, .. } as next) =>
          chunk.merge_next(next) |> ignore
        _ => ()
      }
      if chunk.memory.length < new_length {
        let new_memory = allocate(new_length).unwrap()
        memory_copy_ffi(self.offset, new_memory.offset, self.length)
        Some(new_memory)
      } else {
        chunk.occupied = true
        chunk.split(new_length) |> ignore
        memory_copy_ffi(self.offset, chunk.memory.offset, self.length)
        Some(chunk.memory)
      }
    } else {
      None
    }
  }
}
