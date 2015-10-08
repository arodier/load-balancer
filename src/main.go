
package main

import (
    "fmt"
    "net/http"
    "os"
    "os/signal"
    "log"
)

func handler(w http.ResponseWriter, r *http.Request) {

    h,_ := os.Hostname()
    fmt.Fprintf(w, "Hi there, I'm served from %s!", h)
}

func main() {
    http.HandleFunc("/", handler)
    http.ListenAndServe(":8484", nil)

    // Properly handle Ctrl-C
    channel := make(chan os.Signal, 1)
    signal.Notify(channel, os.Interrupt)
    go func() {
        for _ = range channel {
            log.Printf("Receiving interrupt. Bye...")
            os.Exit(0)
        }
    }()

}
