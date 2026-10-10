package steamstats

import (
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

var (
	libraryPathRE = regexp.MustCompile(`"path"\s+"([^"]+)"`)
	appIDRE       = regexp.MustCompile(`"appid"\s+"(\d+)"`)
	nameRE        = regexp.MustCompile(`"name"\s+"([^"]+)"`)
	stateFlagsRE  = regexp.MustCompile(`"StateFlags"\s+"(\d+)"`)
)

var skipNameTokens = []string{
	"proton",
	"steamworks",
	"steam linux runtime",
	"redistributable",
}

func isToolingName(name string) bool {
	lower := strings.ToLower(name)
	for _, token := range skipNameTokens {
		if strings.Contains(lower, token) {
			return true
		}
	}
	return false
}

func libraryPaths(steamDir string) ([]string, error) {
	paths := []string{}
	seen := map[string]struct{}{}

	steamapps := filepath.Join(steamDir, "steamapps")
	if st, err := os.Stat(steamapps); err == nil && st.IsDir() {
		paths = append(paths, steamapps)
		if abs, err := filepath.EvalSymlinks(steamapps); err == nil {
			seen[abs] = struct{}{}
		}
	}

	data, err := os.ReadFile(filepath.Join(steamapps, "libraryfolders.vdf"))
	if err != nil {
		return paths, nil
	}

	for _, match := range libraryPathRE.FindAllStringSubmatch(string(data), -1) {
		lib := filepath.Join(strings.ReplaceAll(match[1], `\\`, `\`), "steamapps")
		st, err := os.Stat(lib)
		if err != nil || !st.IsDir() {
			continue
		}
		abs, err := filepath.EvalSymlinks(lib)
		if err != nil {
			abs = lib
		}
		if _, ok := seen[abs]; ok {
			continue
		}
		seen[abs] = struct{}{}
		paths = append(paths, lib)
	}
	return paths, nil
}

func scanLibrary(steamDir string, private map[string]struct{}) (int, map[string]string, []RunningGame, error) {
	libs, err := libraryPaths(steamDir)
	if err != nil {
		return 0, nil, nil, err
	}

	names := map[string]string{}
	running := []RunningGame{}
	seen := map[string]struct{}{}
	installed := 0

	for _, lib := range libs {
		matches, err := filepath.Glob(filepath.Join(lib, "appmanifest_*.acf"))
		if err != nil {
			return 0, nil, nil, err
		}
		for _, manifest := range matches {
			data, err := os.ReadFile(manifest)
			if err != nil {
				continue
			}
			text := string(data)
			appMatch := appIDRE.FindStringSubmatch(text)
			if len(appMatch) < 2 {
				continue
			}
			appid := appMatch[1]
			if _, ok := seen[appid]; ok {
				continue
			}
			seen[appid] = struct{}{}

			name := "App " + appid
			if nameMatch := nameRE.FindStringSubmatch(text); len(nameMatch) >= 2 && nameMatch[1] != "" {
				name = nameMatch[1]
			}
			names[appid] = name

			if !isToolingName(name) {
				installed++
			}

			flags := 0
			if flagMatch := stateFlagsRE.FindStringSubmatch(text); len(flagMatch) >= 2 {
				flags, _ = strconv.Atoi(flagMatch[1])
			}
			if flags&32 == 0 {
				continue
			}
			if _, skip := private[appid]; skip {
				continue
			}
			running = append(running, RunningGame{AppID: appid, Name: name})
		}
	}
	return installed, names, running, nil
}

func iconPathForApp(steamDir, appid string) string {
	root := filepath.Join(steamDir, "appcache", "librarycache", appid)
	if st, err := os.Stat(root); err != nil || !st.IsDir() {
		return ""
	}
	for _, want := range []string{"library_600x900.jpg", "library_capsule.jpg"} {
		var matches []string
		_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return nil
			}
			if strings.EqualFold(d.Name(), want) {
				matches = append(matches, path)
			}
			return nil
		})
		if len(matches) == 0 {
			continue
		}
		sort.Strings(matches)
		return matches[0]
	}
	return ""
}

func buildPlayedGames(steamDir string, names map[string]string, records []playedRecord, private map[string]struct{}) []PlayedGame {
	out := []PlayedGame{}
	for _, rec := range records {
		if rec.LastPlayed <= 0 {
			continue
		}
		if _, skip := private[rec.AppID]; skip {
			continue
		}
		name := names[rec.AppID]
		if name == "" || isToolingName(name) {
			continue
		}
		out = append(out, PlayedGame{
			AppID:       rec.AppID,
			Name:        name,
			LastPlayed:  rec.LastPlayed,
			PlaytimeMin: rec.PlaytimeMin,
			IconPath:    iconPathForApp(steamDir, rec.AppID),
		})
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].LastPlayed > out[j].LastPlayed
	})
	if len(out) > 3 {
		out = out[:3]
	}
	return out
}

func steamRunning() bool {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return false
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		data, err := os.ReadFile(filepath.Join("/proc", e.Name(), "cmdline"))
		if err != nil || len(data) == 0 {
			continue
		}
		cmd := strings.ReplaceAll(string(data), "\x00", " ")
		if strings.Contains(cmd, "/Steam/ubuntu12_32/steam") {
			return true
		}
		if strings.Contains(cmd, "steam") && strings.Contains(cmd, "-srt-logger-opened") {
			return true
		}
	}
	return false
}

var downloadRateRE = regexp.MustCompile(`Current download rate:\s*([0-9.]+)\s*Mbps`)

func downloadBPS(steamDir string) int {
	data, err := os.ReadFile(filepath.Join(steamDir, "logs", "content_log.txt"))
	if err != nil {
		return 0
	}
	text := string(data)
	lines := strings.Split(text, "\n")
	if len(lines) > 400 {
		lines = lines[len(lines)-400:]
	}
	rate := ""
	for _, line := range lines {
		m := downloadRateRE.FindStringSubmatch(line)
		if len(m) == 2 {
			rate = m[1]
		}
	}
	if rate == "" {
		return 0
	}
	mbps, err := strconv.ParseFloat(rate, 64)
	if err != nil {
		return 0
	}
	return int(mbps * 125000)
}
