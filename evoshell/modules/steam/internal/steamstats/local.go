package steamstats

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"

	"github.com/jslay88/vdf"
)

type playedRecord struct {
	AppID       string
	LastPlayed  int
	PlaytimeMin int
}

func findLocalconfig(steamDir string) string {
	matches, err := filepath.Glob(filepath.Join(steamDir, "userdata", "*", "config", "localconfig.vdf"))
	if err != nil {
		return ""
	}
	best := ""
	var bestMtime int64
	for _, path := range matches {
		st, err := os.Stat(path)
		if err != nil {
			continue
		}
		mtime := st.ModTime().Unix()
		if mtime >= bestMtime {
			best = path
			bestMtime = mtime
		}
	}
	return best
}

func loadLocalconfig(path string) (int, []playedRecord, map[string]struct{}, error) {
	private := map[string]struct{}{}
	played := []playedRecord{}
	if path == "" {
		return 0, played, private, nil
	}

	doc, err := vdf.ParseFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return 0, played, private, nil
		}
		return 0, played, private, err
	}

	uid := filepath.Base(filepath.Dir(filepath.Dir(path)))
	for _, id := range parsePrivateAppIDs(findStringInDoc(doc, "PrivateApps_"+uid)) {
		private[id] = struct{}{}
	}

	playtime := 0
	root := doc.Get("UserLocalConfigStore")
	if root == nil {
		return 0, played, private, nil
	}
	software := root.Get("Software")
	if software == nil {
		return playtime, played, private, nil
	}
	valve := software.Get("Valve")
	if valve == nil {
		return playtime, played, private, nil
	}
	steam := valve.Get("Steam")
	if steam == nil {
		return playtime, played, private, nil
	}
	apps := steam.Get("apps")
	if apps == nil || !apps.IsObject {
		return playtime, played, private, nil
	}

	for _, app := range apps.Children {
		if !app.IsObject {
			continue
		}
		pt := 0
		if n := app.Get("Playtime"); n != nil {
			pt, _ = strconv.Atoi(n.Value)
			playtime += pt
		}
		last := 0
		if n := app.Get("LastPlayed"); n != nil {
			last, _ = strconv.Atoi(n.Value)
		}
		if last == 0 && pt == 0 {
			continue
		}
		played = append(played, playedRecord{
			AppID:       app.Key,
			LastPlayed:  last,
			PlaytimeMin: pt,
		})
	}
	return playtime, played, private, nil
}

func parsePrivateAppIDs(raw string) []string {
	if raw == "" {
		return nil
	}
	var values []any
	if err := json.Unmarshal([]byte(raw), &values); err != nil {
		return nil
	}
	out := make([]string, 0, len(values))
	for _, v := range values {
		switch t := v.(type) {
		case float64:
			out = append(out, strconv.FormatInt(int64(t), 10))
		case string:
			if t != "" {
				out = append(out, t)
			}
		}
	}
	return out
}

func findStringInDoc(doc *vdf.Document, key string) string {
	if doc == nil {
		return ""
	}
	for _, root := range doc.Roots {
		if s := findString(root, key); s != "" {
			return s
		}
	}
	return ""
}

func findString(n *vdf.Node, key string) string {
	if n == nil {
		return ""
	}
	if !n.IsObject {
		if n.Key == key {
			return n.Value
		}
		return ""
	}
	if child := n.Get(key); child != nil && !child.IsObject {
		return child.Value
	}
	for _, child := range n.Children {
		if s := findString(child, key); s != "" {
			return s
		}
	}
	return ""
}
