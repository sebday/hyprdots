package vdfbin

import (
	"encoding/binary"
	"fmt"
	"io"
)

const (
	typeNone    = 0x00
	typeString  = 0x01
	typeInt32   = 0x02
	typeFloat32 = 0x03
	typePointer = 0x04
	typeWideStr = 0x05
	typeColor   = 0x06
	typeUint64  = 0x07
	typeEnd     = 0x08
	typeInt64   = 0x0A
)

// Map is a parsed binary VDF object tree.
type Map map[string]any

// Load parses binary VDF bytes. When keyTable is non-empty, keys are int32 indexes.
func Load(data []byte, keyTable []string) (Map, error) {
	r := &reader{data: data}
	return r.readMap(keyTable)
}

type reader struct {
	data []byte
	pos  int
}

func (r *reader) read(n int) ([]byte, error) {
	if r.pos+n > len(r.data) {
		return nil, io.ErrUnexpectedEOF
	}
	out := r.data[r.pos : r.pos+n]
	r.pos += n
	return out, nil
}

func (r *reader) readByte() (byte, error) {
	b, err := r.read(1)
	if err != nil {
		return 0, err
	}
	return b[0], nil
}

func (r *reader) readCString(wide bool) (string, error) {
	start := r.pos
	for r.pos < len(r.data) {
		if wide {
			if r.pos+1 < len(r.data) && r.data[r.pos] == 0 && r.data[r.pos+1] == 0 {
				s := string(r.data[start:r.pos])
				r.pos += 2
				return s, nil
			}
			r.pos += 2
			continue
		}
		if r.data[r.pos] == 0 {
			s := string(r.data[start:r.pos])
			r.pos++
			return s, nil
		}
		r.pos++
	}
	return "", io.ErrUnexpectedEOF
}

func (r *reader) readKey(keyTable []string) (string, error) {
	if len(keyTable) > 0 {
		raw, err := r.read(4)
		if err != nil {
			return "", err
		}
		idx := int(int32(binary.LittleEndian.Uint32(raw)))
		if idx < 0 || idx >= len(keyTable) {
			return "", fmt.Errorf("key table index out of range: %d", idx)
		}
		return keyTable[idx], nil
	}
	return r.readCString(false)
}

func (r *reader) readMap(keyTable []string) (Map, error) {
	out := make(Map)
	for {
		t, err := r.readByte()
		if err != nil {
			return nil, err
		}
		if t == typeEnd {
			return out, nil
		}

		key, err := r.readKey(keyTable)
		if err != nil {
			return nil, err
		}

		switch t {
		case typeNone:
			child, err := r.readMap(keyTable)
			if err != nil {
				return nil, err
			}
			out[key] = child
		case typeString:
			val, err := r.readCString(false)
			if err != nil {
				return nil, err
			}
			out[key] = val
		case typeWideStr:
			val, err := r.readCString(true)
			if err != nil {
				return nil, err
			}
			out[key] = val
		case typeInt32, typePointer, typeColor:
			raw, err := r.read(4)
			if err != nil {
				return nil, err
			}
			out[key] = int32(binary.LittleEndian.Uint32(raw))
		case typeUint64:
			raw, err := r.read(8)
			if err != nil {
				return nil, err
			}
			out[key] = binary.LittleEndian.Uint64(raw)
		case typeInt64:
			raw, err := r.read(8)
			if err != nil {
				return nil, err
			}
			out[key] = int64(binary.LittleEndian.Uint64(raw))
		case typeFloat32:
			raw, err := r.read(4)
			if err != nil {
				return nil, err
			}
			out[key] = binary.LittleEndian.Uint32(raw)
		default:
			return nil, fmt.Errorf("unknown binary vdf type 0x%02x at offset %d", t, r.pos-1)
		}
	}
}
