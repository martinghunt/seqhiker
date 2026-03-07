package main

import (
	"flag"
	"log"
)

func main() {
	listenAddr := flag.String("listen", ":9000", "TCP listen address")
	tileCacheMB := flag.Int("tile-cache-mb", 512, "tile cache size in MiB")
	flag.Parse()

	engine := NewEngine()
	if *tileCacheMB > 0 {
		engine.SetTileCacheMaxBytes(int64(*tileCacheMB) << 20)
	}

	err := StartServer(*listenAddr, engine)
	if err != nil {
		log.Fatal(err)
	}
}
