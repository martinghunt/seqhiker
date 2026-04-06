package main

import (
	"flag"
	"fmt"
	"log"

	"seqhiker/zem"
)

func main() {
	listenAddr := flag.String("listen", ":9000", "TCP listen address")
	tileCacheMB := flag.Int("tile-cache-mb", 512, "tile cache size in MiB")
	showVersion := flag.Bool("version", false, "print zem version and exit")
	flag.Parse()
	if *showVersion {
		fmt.Println(zem.ZemVersion)
		return
	}

	engine := zem.NewEngine()
	if *tileCacheMB > 0 {
		engine.SetTileCacheMaxBytes(int64(*tileCacheMB) << 20)
	}

	err := zem.StartServer(*listenAddr, engine)
	if err != nil {
		log.Fatal(err)
	}
}
