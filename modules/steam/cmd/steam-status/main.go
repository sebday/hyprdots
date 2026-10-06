package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"

	"evoshell/modules/steam/internal/steamstats"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}

	steamDir := os.Getenv("STEAM_DIR")
	if steamDir == "" {
		steamDir = filepath.Join(os.Getenv("HOME"), ".local/share/Steam")
	}
	steamBin := os.Getenv("STEAM_BIN")
	if steamBin == "" {
		steamBin = "steam"
	}

	switch os.Args[1] {
	case "popup":
		printJSON(steamstats.Compute(steamDir))
	case "launch":
		if len(os.Args) < 3 || os.Args[2] == "" {
			fmt.Fprintf(os.Stderr, "usage: %s launch <appid>\n", os.Args[0])
			os.Exit(1)
		}
		if err := startDetached(steamBin, "-applaunch", os.Args[2]); err != nil {
			os.Exit(1)
		}
	case "open", "open-downloads":
		if err := openSteam(steamBin); err != nil {
			os.Exit(1)
		}
	default:
		usage()
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintf(os.Stderr, "usage: %s popup|launch <appid>|open\n", os.Args[0])
}

func printJSON(result steamstats.Result) {
	out, err := json.Marshal(result)
	if err != nil {
		out, _ = json.Marshal(steamstats.Result{OK: false, Error: err.Error()})
	}
	fmt.Println(string(out))
}

func openSteam(steamBin string) error {
	if _, err := exec.LookPath("gtk-launch"); err == nil {
		if _, err := exec.LookPath("uwsm-app"); err == nil {
			return startSetsid("uwsm-app", "--", "gtk-launch", "steam")
		}
		return startDetached("gtk-launch", "steam")
	}
	return startDetached(steamBin)
}

func startDetached(name string, args ...string) error {
	if _, err := exec.LookPath(name); err != nil {
		return err
	}
	cmd := exec.Command(name, args...)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	return cmd.Start()
}

func startSetsid(name string, args ...string) error {
	if _, err := exec.LookPath(name); err != nil {
		return err
	}
	cmd := exec.Command(name, args...)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	return cmd.Start()
}
