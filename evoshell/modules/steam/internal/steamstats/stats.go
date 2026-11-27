package steamstats

import (
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"evoshell/modules/steam/internal/vdfbin"
	"github.com/jslay88/vdf"
)

const (
	magicPackageV27 = 0x06565527
	magicPackageV28 = 0x06565528
	packageEnd      = 0xFFFFFFFF
)

type PlayedGame struct {
	AppID       string `json:"appid"`
	Name        string `json:"name"`
	LastPlayed  int    `json:"last_played"`
	PlaytimeMin int    `json:"playtime_min"`
	IconPath    string `json:"icon_path"`
}

type RunningGame struct {
	AppID string `json:"appid"`
	Name  string `json:"name"`
}

type Result struct {
	OK               bool          `json:"ok"`
	Error            string        `json:"error,omitempty"`
	Running          bool          `json:"running"`
	DownloadBPS      int           `json:"download_bps"`
	InstalledCount   int           `json:"installed_count"`
	OwnedCount       int           `json:"owned_count"`
	LibraryCount     int           `json:"library_count"`
	PlayedGames      []PlayedGame  `json:"played_games"`
	RunningGames     []RunningGame `json:"running_games"`
	TotalPlaytimeMin int           `json:"total_playtime_min"`
}

func fail(msg string) Result {
	return Result{
		OK:           false,
		Error:        msg,
		PlayedGames:  []PlayedGame{},
		RunningGames: []RunningGame{},
	}
}

func Compute(steamDir string) Result {
	info, err := os.Stat(steamDir)
	if err != nil || !info.IsDir() {
		return fail("Steam directory not found")
	}

	localconfig := findLocalconfig(steamDir)
	playtime, playedRecords, private, err := loadLocalconfig(localconfig)
	if err != nil {
		return fail(err.Error())
	}

	installed, names, running, err := scanLibrary(steamDir, private)
	if err != nil {
		return fail(err.Error())
	}
	owned, err := ownedCount(steamDir)
	if err != nil {
		return fail(err.Error())
	}

	played := buildPlayedGames(steamDir, names, playedRecords, private)
	return Result{
		OK:               true,
		Running:          steamRunning(),
		DownloadBPS:      downloadBPS(steamDir),
		InstalledCount:   installed,
		OwnedCount:       owned,
		LibraryCount:     installed,
		PlayedGames:      played,
		RunningGames:     running,
		TotalPlaytimeMin: playtime,
	}
}

func ownedCount(steamDir string) (int, error) {
	owned, err := ownedAppIDs(steamDir)
	if err != nil {
		return 0, err
	}
	if len(owned) == 0 {
		return 0, nil
	}
	types, err := appInfoTypeMap(steamDir)
	if err != nil {
		return 0, err
	}
	if len(types) == 0 {
		return 0, nil
	}
	count := 0
	for appid := range owned {
		if types[appid] == "game" {
			count++
		}
	}
	return count, nil
}

func ownedAppIDs(steamDir string) (map[uint32]struct{}, error) {
	path := filepath.Join(steamDir, "appcache", "packageinfo.vdf")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	if len(data) < 8 {
		return nil, nil
	}

	magic := binary.LittleEndian.Uint32(data[:4])
	var headerSkip int
	switch magic {
	case magicPackageV27:
		headerSkip = 24
	case magicPackageV28:
		headerSkip = 32
	default:
		return nil, nil
	}

	return ownedAppIDsFromReader(data, headerSkip)
}

func ownedAppIDsFromReader(data []byte, headerSkip int) (map[uint32]struct{}, error) {
	owned := map[uint32]struct{}{}
	offset := 8
	for offset+4 <= len(data) {
		pkgID := binary.LittleEndian.Uint32(data[offset : offset+4])
		offset += 4
		if pkgID == packageEnd {
			break
		}
		if offset+headerSkip > len(data) {
			break
		}
		offset += headerSkip

		block, err := vdfbin.Load(data[offset:], nil)
		if err != nil {
			return nil, err
		}
		consumed, err := measureBinaryVDF(data[offset:])
		if err != nil {
			return nil, err
		}
		offset += consumed

		for _, value := range block {
			pkg, ok := asMap(value)
			if !ok {
				continue
			}
			appids, ok := asMap(pkg["appids"])
			if !ok {
				continue
			}
			for _, raw := range appids {
				appid, ok := asUint(raw)
				if !ok {
					continue
				}
				owned[appid] = struct{}{}
			}
		}
	}
	return owned, nil
}

func measureBinaryVDF(data []byte) (int, error) {
	pos := 0
	depth := 0
	for pos < len(data) {
		t := data[pos]
		pos++
		if t == typeEndVDF {
			if depth == 0 {
				return pos, nil
			}
			depth--
			continue
		}

		// key: null-terminated string
		start := pos
		for pos < len(data) && data[pos] != 0 {
			pos++
		}
		if pos >= len(data) {
			return 0, fmt.Errorf("unterminated key")
		}
		pos++
		_ = start

		switch t {
		case 0x00:
			depth++
		case 0x01, 0x05:
			for pos < len(data) {
				if t == 0x05 {
					if pos+1 < len(data) && data[pos] == 0 && data[pos+1] == 0 {
						pos += 2
						break
					}
					pos += 2
					continue
				}
				if data[pos] == 0 {
					pos++
					break
				}
				pos++
			}
		case 0x02, 0x03, 0x04, 0x06:
			pos += 4
		case 0x07, 0x0A:
			pos += 8
		default:
			return 0, fmt.Errorf("unknown type 0x%02x", t)
		}
	}
	return 0, fmt.Errorf("binary vdf not terminated")
}

const typeEndVDF = 0x08

const (
	magicAppInfoV42 = 0x0756442A
	appTypeGame     = 1
)

func appInfoTypeMap(steamDir string) (map[uint32]string, error) {
	types := map[uint32]string{}
	data, err := os.ReadFile(filepath.Join(steamDir, "appcache", "appinfo.vdf"))
	if err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	if err == nil && len(data) >= 8 {
		parsed, err := parseLegacyAppInfo(data)
		if err != nil {
			return nil, err
		}
		for id, kind := range parsed {
			types[id] = kind
		}
	}

	shards, err := appInfoShardTypes(filepath.Join(steamDir, "appcache", "appinfo"))
	if err != nil {
		return nil, err
	}
	for id, kind := range shards {
		types[id] = kind
	}
	return types, nil
}

func parseLegacyAppInfo(data []byte) (map[uint32]string, error) {
	switch string(data[:4]) {
	case "(DV\x07":
		return parseAppInfoV40(data)
	case ")DV\x07":
		return parseAppInfoV41(data)
	default:
		return map[uint32]string{}, nil
	}
}

// Steam replaced appinfo.vdf with 256 shards. Each index entry already stores
// common/type, so the game count does not need the binary VDF body.
func appInfoShardTypes(dir string) (map[uint32]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return map[uint32]string{}, nil
		}
		return nil, err
	}
	types := map[uint32]string{}
	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() || !strings.HasPrefix(name, "appinfo_") || !strings.HasSuffix(name, ".vdf") {
			continue
		}
		data, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return nil, err
		}
		parsed, err := parseAppInfoShard(data)
		if err != nil {
			return nil, err
		}
		for id, kind := range parsed {
			types[id] = kind
		}
	}
	return types, nil
}

func parseAppInfoShard(data []byte) (map[uint32]string, error) {
	types := map[uint32]string{}
	if len(data) < 44 || binary.LittleEndian.Uint32(data[:4]) != magicAppInfoV42 {
		return types, nil
	}
	count := int(binary.LittleEndian.Uint32(data[16:20]))
	indexSize := int(binary.LittleEndian.Uint32(data[20:24]))
	if count < 0 || indexSize < 0 || 44+indexSize > len(data) {
		return nil, fmt.Errorf("appinfo shard header is truncated")
	}
	off := 44
	end := 44 + indexSize
	// Summary starts after app id, data offset, data size, and summary size.
	// Type follows change number, last updated, PICS token, prerelease, and SHA-1.
	const typeRel = 4 + 4 + 8 + 1 + 20
	for range count {
		if off+16 > end {
			return nil, fmt.Errorf("appinfo shard index is truncated")
		}
		appid := binary.LittleEndian.Uint32(data[off : off+4])
		summary := int(binary.LittleEndian.Uint32(data[off+12 : off+16]))
		if summary < 0 || off+16+summary > end {
			return nil, fmt.Errorf("appinfo shard entry is truncated")
		}
		if appid != 0 && summary >= typeRel+4 {
			typ := binary.LittleEndian.Uint32(data[off+16+typeRel : off+16+typeRel+4])
			if typ == appTypeGame {
				types[appid] = "game"
			}
		}
		off += 16 + summary
	}
	return types, nil
}

func parseAppInfoV40(data []byte) (map[uint32]string, error) {
	types := map[uint32]string{}
	sectionSize := 68
	i := 8
	for i+sectionSize <= len(data)-4 {
		appid := binary.LittleEndian.Uint32(data[i : i+4])
		entrySize := binary.LittleEndian.Uint32(data[i+4 : i+8])
		vdfSize := int(entrySize) - (sectionSize - 8)
		i += sectionSize
		if vdfSize <= 0 || i+vdfSize > len(data) {
			break
		}
		block, err := vdfbin.Load(data[i:i+vdfSize], nil)
		if err != nil {
			return nil, err
		}
		i += vdfSize
		if appType := extractAppType(block); appid != 0 && appType != "" {
			types[appid] = appType
		}
	}
	return types, nil
}

func parseAppInfoV41(data []byte) (map[uint32]string, error) {
	types := map[uint32]string{}
	keyTableOffset := int64(binary.LittleEndian.Uint64(data[8:16]))
	keyCount := int(binary.LittleEndian.Uint32(data[keyTableOffset : keyTableOffset+4]))

	keyTable := make([]string, 0, keyCount)
	tableI := int(keyTableOffset) + 4
	for range keyCount {
		start := tableI
		for tableI < len(data) && data[tableI] != 0 {
			tableI++
		}
		if tableI >= len(data) {
			break
		}
		keyTable = append(keyTable, string(data[start:tableI]))
		tableI++
	}

	sectionSize := 68
	i := 16
	for i+sectionSize <= int(keyTableOffset)-4 {
		appid := binary.LittleEndian.Uint32(data[i : i+4])
		entrySize := binary.LittleEndian.Uint32(data[i+4 : i+8])
		vdfSize := int(entrySize) - (sectionSize - 8)
		i += sectionSize
		if vdfSize <= 0 || i+vdfSize > len(data) {
			break
		}
		block, err := vdfbin.Load(data[i:i+vdfSize], keyTable)
		if err != nil {
			return nil, err
		}
		i += vdfSize
		if appType := extractAppType(block); appid != 0 && appType != "" {
			types[appid] = appType
		}
	}
	return types, nil
}

func extractAppType(block vdfbin.Map) string {
	for _, value := range block {
		child, ok := asMap(value)
		if !ok {
			continue
		}
		common, ok := asMap(child["common"])
		if !ok {
			continue
		}
		if raw, ok := common["type"]; ok {
			return strings.ToLower(fmt.Sprint(raw))
		}
	}
	return ""
}

func asMap(value any) (vdfbin.Map, bool) {
	switch v := value.(type) {
	case vdfbin.Map:
		return v, true
	case map[string]any:
		out := vdfbin.Map(v)
		return out, true
	case vdf.Map:
		out := vdfbin.Map{}
		for k, raw := range v {
			out[k] = raw
		}
		return out, true
	default:
		return nil, false
	}
}

func asUint(value any) (uint32, bool) {
	switch v := value.(type) {
	case uint32:
		return v, true
	case int:
		if v < 0 {
			return 0, false
		}
		return uint32(v), true
	case int32:
		if v < 0 {
			return 0, false
		}
		return uint32(v), true
	case string:
		n, err := strconv.ParseUint(v, 10, 32)
		if err != nil {
			return 0, false
		}
		return uint32(n), true
	default:
		return 0, false
	}
}
