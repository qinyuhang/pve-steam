package main

import (
	"fmt"
	"net/http"
	"os"
	"os/exec"
)

func run(cmd string, args ...string) string {
	out, err := exec.Command(cmd, args...).CombinedOutput()
	if err != nil {
		return err.Error() + "\n" + string(out)
	}
	return string(out)
}

func auth(r *http.Request, token string) bool {
	return r.URL.Query().Get("token") == token
}

func main() {
	vmid := os.Getenv("VMID")
	token := os.Getenv("TOKEN")
	port := os.Getenv("PORT")

	if vmid == "" || token == "" {
		panic("VMID and TOKEN must be set")
	}

	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/start", func(w http.ResponseWriter, r *http.Request) {
		if !auth(r, token) { http.Error(w,"forbidden",403); return }
		fmt.Fprint(w, run("qm", "start", vmid))
	})

	http.HandleFunc("/stop", func(w http.ResponseWriter, r *http.Request) {
		if !auth(r, token) { http.Error(w,"forbidden",403); return }
		fmt.Fprint(w, run("qm", "shutdown", vmid))
	})

	http.HandleFunc("/status", func(w http.ResponseWriter, r *http.Request) {
		if !auth(r, token) { http.Error(w,"forbidden",403); return }
		fmt.Fprint(w, run("qm", "status", vmid))
	})

	http.ListenAndServe("0.0.0.0:"+port, nil)
}
