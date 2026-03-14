package main

import (
	"flag"
	"fmt"
	"log"
)

func main() {
	listenAddr := flag.String("listen", ":9000", "TCP listen address")
	tileCacheMB := flag.Int("tile-cache-mb", 512, "tile cache size in MiB")
	showVersion := flag.Bool("version", false, "print zem version and exit")
	flag.Parse()
	if *showVersion {
		fmt.Println(ZemVersion)
		return
	}

	engine := NewEngine()
	if *tileCacheMB > 0 {
		engine.SetTileCacheMaxBytes(int64(*tileCacheMB) << 20)
	}

	err := StartServer(*listenAddr, engine)
	if err != nil {
		log.Fatal(err)
	}
}
