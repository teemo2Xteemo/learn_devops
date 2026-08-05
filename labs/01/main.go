package main

import (
    "fmt"
    "net/http"
)
func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "DevOps Daily - Lesson 01 OK")
    })
	
	fmt.Println("Server is running on http://localhost:8080")
	fmt.Println("Press Ctrl+C to stop the server")

    http.ListenAndServe(":8080", nil)
}