package main

import (
	"fmt"
	"github.com/gorilla/mux"
	"net/http"
)

func main() {
	r := mux.NewRouter()

	r.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello {{cookiecutter.full_name}} 👋🏻.")
	})

	fmt.Println("Server listening at port 80")
	http.ListenAndServe(":80", r)
}
