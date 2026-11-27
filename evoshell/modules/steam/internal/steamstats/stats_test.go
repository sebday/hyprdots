package steamstats

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"testing"
)

func TestAppInfoShardMarksGames(t *testing.T) {
	dir := t.TempDir()
	shardDir := filepath.Join(dir, "appcache", "appinfo")
	if err := os.MkdirAll(shardDir, 0o755); err != nil {
		t.Fatal(err)
	}
	shard := appInfoShard(
		appInfoIndexEntry(220, appTypeGame),
		appInfoIndexEntry(7, 4),
	)
	if err := os.WriteFile(filepath.Join(shardDir, "appinfo_00.vdf"), shard, 0o644); err != nil {
		t.Fatal(err)
	}

	types, err := appInfoTypeMap(dir)
	if err != nil {
		t.Fatal(err)
	}
	if types[220] != "game" {
		t.Fatalf("app 220 type = %q", types[220])
	}
	if _, ok := types[7]; ok {
		t.Fatalf("tool 7 was classified as %q", types[7])
	}
}

func TestMissingAppInfoIsEmpty(t *testing.T) {
	types, err := appInfoTypeMap(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if len(types) != 0 {
		t.Fatalf("types = %v", types)
	}
}

func appInfoShard(entries ...[]byte) []byte {
	index := []byte{}
	for _, entry := range entries {
		index = append(index, entry...)
	}
	header := make([]byte, 44)
	binary.LittleEndian.PutUint32(header[0:], magicAppInfoV42)
	binary.LittleEndian.PutUint32(header[4:], 1)
	binary.LittleEndian.PutUint32(header[12:], 256)
	binary.LittleEndian.PutUint32(header[16:], uint32(len(entries)))
	binary.LittleEndian.PutUint32(header[20:], uint32(len(index)))
	return append(header, index...)
}

func appInfoIndexEntry(appid, typ uint32) []byte {
	const summary = 4 + 4 + 8 + 1 + 20 + 4
	entry := make([]byte, 16+summary)
	binary.LittleEndian.PutUint32(entry[0:], appid)
	binary.LittleEndian.PutUint32(entry[12:], summary)
	binary.LittleEndian.PutUint32(entry[16+4+4+8+1+20:], typ)
	return entry
}
